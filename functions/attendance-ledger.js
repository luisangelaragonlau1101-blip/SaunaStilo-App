'use strict';

// Backward-compatible ledger for the existing Android 3.6 and web clients.
// All four attendance times live in asistencias/<uid>_<Mexico-day>.
// This module never writes salaries, fines, bonuses, or payroll amounts.
const ROLES = new Set(['trabajador', 'maestro', 'almacenista']);
const ZONES = Object.freeze([
  {name:'Sauna Stilo',lat:19.26247565075755,lon:-98.89430986717343,radius:35},
  {name:'Sauna Stilo',lat:19.26236781757325,lon:-98.89404650777578,radius:20},
  {name:'Sauna Stilo',lat:19.2622796818614,lon:-98.89399453997612,radius:20},
  {name:'Sauna Stilo',lat:19.262236850336194,lon:-98.89410702511668,radius:20},
  {name:'Sauna Stilo',lat:19.26225529052317,lon:-98.89396402984858,radius:20},
  {name:'Sauna Stilo',lat:19.262421336025,lon:-98.89423744753003,radius:10},
]);
const STEPS = Object.freeze({entrada:'horaEntrada',solicitar_comida:'salidaComidaSolicitada',regreso_comida:'regresoComidaReal',salida:'horaSalida'});
const TITLES = Object.freeze({horaEntrada:'Entrada registrada',salidaComidaSolicitada:'Solicitud de comida',salidaComidaReal:'Salida a comer autorizada',regresoComidaReal:'Regreso de comida registrado',horaSalida:'Salida de jornada registrada'});
function milliseconds(value) {
  if (value == null) return null;
  const n = value instanceof Date ? value.getTime() : typeof value.toMillis === 'function' ? value.toMillis() : NaN;
  return Number.isFinite(n) ? n : null;
}
function mexicoParts(now) {
  return Object.fromEntries(new Intl.DateTimeFormat('en-CA', {timeZone:'America/Mexico_City',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(now).map(p=>[p.type,p.value]));
}
function dateKey(now) { const p=mexicoParts(now);return p.year+p.month+p.day; }
function distance(a,b,x,y) {const r=Math.PI/180, dlat=(x-a)*r, dlon=(y-b)*r;const h=Math.sin(dlat/2)**2+Math.cos(a*r)*Math.cos(x*r)*Math.sin(dlon/2)**2;return 6371000*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)));}
function authorizedZone(lat,lon) {
  if (typeof lat!=='number'||typeof lon!=='number'||!Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180) return null;
  return ZONES.find(z=>distance(lat,lon,z.lat,z.lon)<=z.radius)||null;
}
function ledgerSummary(d) {
  const start=milliseconds(d.horaEntrada), end=milliseconds(d.horaSalida), lunch=milliseconds(d.salidaComidaReal), back=milliseconds(d.regresoComidaReal);
  const issues=[];
  if(start===null) issues.push('sin_entrada');
  if(end===null) issues.push('sin_salida');
  if(start!==null&&end!==null&&end<start) issues.push('salida_anterior_a_entrada');
  if(lunch!==null&&start!==null&&lunch<start) issues.push('comida_anterior_a_entrada');
  if(back!==null&&lunch===null) issues.push('regreso_sin_salida_a_comer');
  if(lunch!==null&&back===null) issues.push('comida_sin_regreso');
  if(lunch!==null&&back!==null&&back<lunch) issues.push('regreso_anterior_a_comida');
  if(end!==null&&((lunch!==null&&lunch>end)||(back!==null&&back>end))) issues.push('comida_fuera_de_jornada');
  if(d.estatusComida==='pendiente_aprobacion') issues.push('comida_pendiente_de_aprobacion');
  const complete=start!==null&&end!==null&&end>=start;
  const gross=complete?Math.floor((end-start)/60000):null;
  const food=lunch===null&&back===null?0:lunch!==null&&back!==null&&back>=lunch?Math.floor((back-lunch)/60000):null;
  return {version:1,minutosEntreEntradaYSalida:gross,minutosComida:food,minutosSinComida:issues.length===0&&gross!==null&&food!==null?gross-food:null,requiereRevision:issues.length>0,incidencias:issues,soloInformativo:true};
}
function arrivalStatus(profile,now) {
  const m=/^(\d{1,2}):(\d{2})$/.exec(String(profile.horaEntrada||''));
  const scheduled=m&&+m[1]<24&&+m[2]<60?+m[1]*60+ +m[2]:540;
  const raw=profile.toleranciaMinutos;
  const tolerance=typeof raw==='number'&&Number.isFinite(raw)?Math.max(0,Math.min(120,raw)):11;
  const p=mexicoParts(now);
  return +p.hour*60+ +p.minute>scheduled+tolerance?'retardo':'a_tiempo';
}
function makeAttendanceHandler({db,Timestamp,FieldValue,HttpsError,clock=()=>new Date()}) {
  const requireState=(ok,code,message)=>{if(!ok)throw new HttpsError(code,message);};
  return async function updateAttendance(request) {
    const uid=request.auth?.uid, body=request.data||{};
    requireState(typeof uid==='string'&&uid.length>0&&uid.length<=128&&!uid.includes('/'),'unauthenticated','Inicia sesión para registrar tu jornada.');
    const action=body.accion;
    requireState(Object.hasOwn(STEPS,action),'invalid-argument','Acción de asistencia inválida.');
    requireState(!body.trabajadorId||body.trabajadorId===uid,'permission-denied','Solo puedes registrar tu propia jornada.');
    const now=clock(), key=dateKey(now), ref=db.collection('asistencias').doc(`${uid}_${key}`), profileRef=db.collection('usuarios').doc(uid);
    const stamp=Timestamp.fromDate(now);
    return db.runTransaction(async tx=>{
      const nref=db.collection('notificaciones').doc(`jornada_${ref.id}_${action}`);
      const [p,snap,notification]=await Promise.all([tx.get(profileRef),tx.get(ref),tx.get(nref)]);
      const profile=p.exists?p.data():null;
      requireState(profile&&profile.activo!==false&&ROLES.has(profile.rol),'permission-denied','Esta cuenta no registra asistencia. Administración solo supervisa.');
      const old=snap.exists?snap.data():{};
      requireState(!snap.exists||old.trabajadorId===uid,'failed-precondition','El registro necesita revisión de Administración.');
      // Lost-response retries do not create a second record, change a time, or duplicate alerts.
      if(old[STEPS[action]]!=null){
        requireState(milliseconds(old[STEPS[action]])!==null,'failed-precondition','El horario guardado necesita revisión.');
        return {exito:true,yaRegistrada:true,asistenciaId:ref.id,mensaje:'Este movimiento ya estaba registrado. Se conserva su hora original.'};
      }
      const zone=action==='solicitar_comida'?null:authorizedZone(body.latitud,body.longitud);
      requireState(action==='solicitar_comida'||zone,'failed-precondition','Debes estar dentro de una zona autorizada de Sauna Stilo. No se registró una hora ficticia.');
      let patch, message;
      if(action==='entrada'){
        requireState(!old.horaSalida&&!old.salidaComidaReal&&!old.regresoComidaReal,'failed-precondition','La jornada tiene movimientos sin entrada; Administración debe revisarla.');
        requireState(old.estatus!=='incapacidad_pagada','failed-precondition','Hay una incapacidad registrada; solicita la revisión de Administración.');
        const status=old.estatusJustificacion==='aprobada'?'justificado':arrivalStatus(profile,now);
        patch={trabajadorId:uid,fecha:old.fecha||stamp,horaEntrada:stamp,estatus:status,ubicacionValida:true,latitudRegistro:body.latitud,longitudRegistro:body.longitud};
        if(!snap.exists) Object.assign(patch,{horaSalida:null,salidaComidaSolicitada:null,salidaComidaReal:null,regresoComidaReal:null,estatusComida:'ninguna',ubicacionRegresoComidaValida:false,estatusJustificacion:'ninguna',observacionesTrabajador:'',observacionesAdmin:'',historialModificaciones:[],listaBonos:[],listaMultas:[]});
        message='¡Entrada registrada! Tu jornada ya aparece en Asistencias.';
      } else {
        const started=milliseconds(old.horaEntrada);
        requireState(started!==null,'failed-precondition','Primero registra tu entrada de hoy.');
        requireState(started<=now.getTime(),'failed-precondition','La entrada registrada está en el futuro; Administración debe revisarla.');
        requireState(!old.horaSalida,'failed-precondition','La jornada ya terminó; no se puede volver a abrir desde este botón.');
        if(action==='solicitar_comida'){
          requireState(!old.salidaComidaReal&&!old.regresoComidaReal,'failed-precondition','La comida ya tiene movimientos; revisa tu jornada.');
          patch={salidaComidaSolicitada:stamp,estatusComida:'pendiente_aprobacion'};
          message='Solicitud de comida registrada para revisión de Administración.';
        }else if(action==='regreso_comida'){
          const departed=milliseconds(old.salidaComidaReal);
          requireState(departed!==null&&old.estatusComida==='comiendo','failed-precondition','Administración todavía no autoriza tu salida a comer.');
          requireState(departed>=started&&departed<=now.getTime(),'failed-precondition','La hora de comida necesita revisión de Administración.');
          const minutes=Math.floor((now.getTime()-departed)/60000);
          patch={regresoComidaReal:stamp,estatusComida:'finalizada',ubicacionRegresoComidaValida:true};
          message=`¡Regreso registrado! Tu comida duró ${minutes} minutos.`;
        }else{
          patch={horaSalida:stamp};
          message=old.salidaComidaReal&&!old.regresoComidaReal?'Salida registrada. Falta revisar tu regreso de comida antes de cerrar la revisión de nómina.':'¡Felicidades, completaste tu jornada! Tu salida quedó registrada.';
        }
      }
      patch.resumenJornada=ledgerSummary({...old,...patch});
      // Preserve every existing justification, bonus, fine, note and approved edit.
      if(snap.exists) tx.update(ref,patch);else tx.set(ref,patch);
      // A single notification reaches both the employee and Administration via the existing resolver.
      if(!notification.exists) tx.create(nref,{titulo:TITLES[STEPS[action]],mensaje:`${String(profile.nombre||'Integrante').slice(0,140)}: ${message}`,tipo:'asistencia_jornada',destinatarioId:uid,rolesDestinatarios:['admin'],leidosPor:[],creadoPor:'sistema',fecha:stamp,asistenciaId:ref.id,accion:action,ruta:'/asistencia'});
      return {exito:true,asistenciaId:ref.id,mensaje:message,resumenJornada:patch.resumenJornada};
    });
  };
}
function changedTimes(before,after){return Object.keys(TITLES).filter(k=>milliseconds(before[k])!==milliseconds(after[k]));}
module.exports={makeAttendanceHandler,ledgerSummary,changedTimes,milliseconds,dateKey,ZONES};
