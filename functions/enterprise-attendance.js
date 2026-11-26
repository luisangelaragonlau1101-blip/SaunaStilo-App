'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');
const {requireProfile, active} = require('./enterprise-access');
const {dateKey, ZONES, ledgerSummary, milliseconds} = require('./attendance-ledger');

function requireState(ok,code,message) { if (!ok) throw new HttpsError(code,message); }
function id(value) { return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value); }
function gpsAllowed(lat,lon) {
  if (typeof lat !== 'number' || typeof lon !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat)>90 || Math.abs(lon)>180) return false;
  const r=Math.PI/180;
  return ZONES.some(z=>{ const a=Math.sin((lat-z.lat)*r/2)**2+Math.cos(z.lat*r)*Math.cos(lat*r)*Math.sin((lon-z.lon)*r/2)**2; return 6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(Math.max(0,1-a))) <= z.radius; });
}
function receipt(uid,day,data={},profile={},extra={}) {
  return {exito:true,pendingSync:false,supportsManual:profile.asistenciaManualPermitida===true,
    supportsRecording:active(profile) && ['trabajador','maestro','almacenista'].includes(profile.rol),
    requiresLocation:profile.asistenciaManualPermitida!==true,
    supportsPauses:true,asistenciaId:`${uid}_${day}`,day,data:wireDates(data),receiptRevision:String(data.revision || 0),...extra};
}
function wireDates(value) {
  if (value && typeof value.toDate==='function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(wireDates);
  if (value && typeof value==='object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,wireDates(v)]));
  return value;
}
function arrival(profile,now) {
  const parts=Object.fromEntries(new Intl.DateTimeFormat('en-US',{timeZone:'America/Mexico_City',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(now).map(p=>[p.type,p.value]));
  const m=/^(\d{1,2}):(\d{2})$/.exec(String(profile.horaEntrada || ''));
  const schedule=m&&+m[1]<24&&+m[2]<60?+m[1]*60+ +m[2]:540;
  const tolerance=Number.isFinite(profile.toleranciaMinutos)?Math.max(0,Math.min(120,profile.toleranciaMinutos)):11;
  return +parts.hour*60+ +parts.minute>schedule+tolerance?'retardo':'a_tiempo';
}
async function runEnterpriseAttendance({db,uid,data={},now=new Date()}) {
  const profile=await requireProfile(db,uid,HttpsError);
  const action=String(data.action || '').replace(/^attendance-/, '');
  const target=data.userId || uid;
  requireState(id(target) && (target===uid || profile.rol==='admin'),'permission-denied','Solo puedes consultar tu propia jornada.');
  const currentDay=dateKey(now),day=data.day || currentDay;
  requireState(typeof day==='string' && /^\d{8}$/.test(day) && day<=currentDay,'invalid-argument','Revisa el día de la jornada.');
  const ref=db.collection('asistencias').doc(`${target}_${day}`);
  if (action==='state') return receipt(target,day,(await ref.get()).data() || {},profile);
  if (action==='history') {
    requireState(Array.isArray(data.days) && data.days.length<=31,'invalid-argument','Consulta como máximo 31 días.');
    const items=[];
    for (const selected of [...new Set(data.days)]) {
      requireState(typeof selected==='string' && /^\d{8}$/.test(selected) && selected<=currentDay,'invalid-argument','Revisa los días de consulta.');
      items.push(receipt(target,selected,(await db.collection('asistencias').doc(`${target}_${selected}`).get()).data() || {},profile));
    }
    return {items};
  }
  if (action==='sync-page') {
    requireState(profile.rol==='admin','permission-denied','Solo Administración sincroniza el equipo.');
    return {exito:true,day,updated:0,nextToken:null,source:'firestore',mensaje:'La jornada ya utiliza el registro de Firebase; no hay una segunda base que importar.'};
  }
  requireState(['record','pause','approve'].includes(action),'invalid-argument','Movimiento no reconocido.');
  if (action!=='approve') {
    requireState(target===uid && ['trabajador','maestro','almacenista'].includes(profile.rol),'permission-denied','Esta cuenta solo supervisa la jornada.');
    requireState(day===currentDay,'failed-precondition','Los registros personales corresponden al día actual.');
  } else requireState(profile.rol==='admin','permission-denied','Solo Administración autoriza la comida.');
  if (data.requestId!=null) requireState(id(data.requestId),'invalid-argument','Identificador de movimiento inválido.');
  if (action==='pause') requireState(id(data.requestId),'invalid-argument','La pausa necesita un identificador para evitar duplicados.');
  const movement=String(data.movement || '');
  if (action==='record') requireState(['entrada','salida_comida','regreso_comida','salida','solicitar_comida'].includes(movement),'invalid-argument','Movimiento de jornada inválido.');
  const token=data.requestId || `${action}_${movement}_${day}`;
  const op=db.collection('jornada_operaciones').doc(`${uid}_${token}`);
  const normalized={action,target,day,movement,direction:data.direction || null,pauseId:data.pauseId || null,kind:data.kind || null,detail:data.detail || null,manual:data.manual===true};
  const hash=createHash('sha256').update(JSON.stringify(normalized)).digest('hex');
  return db.runTransaction(async tx=>{
    const [actorDoc,record,operation]=await Promise.all([tx.get(db.collection('usuarios').doc(uid)),tx.get(ref),tx.get(op)]);
    const actor=actorDoc.data(),old=record.data() || {};
    requireState(active(actor),'permission-denied','Tu cuenta no está activa.');
    if (action==='approve') requireState(actor.rol==='admin','permission-denied','Tu autorización cambió.');
    else requireState(['trabajador','maestro','almacenista'].includes(actor.rol),'permission-denied','Tu cuenta no registra asistencia.');
    requireState(!record.exists || old.trabajadorId===target,'failed-precondition','El registro requiere revisión de Administración.');
    if (operation.exists) {
      requireState(operation.data().hash===hash,'already-exists','El identificador ya pertenece a otro movimiento.');
      return receipt(target,day,old,actor,{yaRegistrada:true,mensaje:'El movimiento ya estaba guardado; conserva su hora original.'});
    }
    const stamp=Timestamp.fromDate(now),patch={revision:(Number.isInteger(old.revision)?old.revision:0)+1};
    let message='',eventAction=movement || action;
    if (action==='approve') {
      requireState(milliseconds(old.horaEntrada)!==null && !old.horaSalida,'failed-precondition','La jornada no está abierta.');
      if (old.salidaComidaReal) return receipt(target,day,old,actor,{yaRegistrada:true,mensaje:'La salida a comer ya estaba autorizada.'});
      requireState(old.salidaComidaSolicitada && old.estatusComida==='pendiente_aprobacion','failed-precondition','No hay una solicitud de comida pendiente.');
      Object.assign(patch,{salidaComidaReal:stamp,estatusComida:'comiendo',comidaAutorizadaPor:uid});
      message='Salida a comer autorizada.'; eventAction='comida_autorizada';
    } else {
      // No artificial GPS coordinate is written for manual movements.
      const isManual=data.manual===true;
      requireState(!isManual || actor.asistenciaManualPermitida===true,'permission-denied','Administración debe autorizar el registro manual en tu perfil.');
      requireState(isManual || gpsAllowed(data.latitud,data.longitud),'failed-precondition','Registra desde una ubicación autorizada o solicita permiso para registro manual.');
      const location=isManual?{ubicacionValida:false,registroManual:true}:{ubicacionValida:true,latitudRegistro:data.latitud,longitudRegistro:data.longitud,registroManual:false};
      if (action==='record') {
        const field={entrada:'horaEntrada',salida_comida:'salidaComidaReal',regreso_comida:'regresoComidaReal',salida:'horaSalida',solicitar_comida:'salidaComidaSolicitada'}[movement];
        if (old[field]) return receipt(target,day,old,actor,{yaRegistrada:true,mensaje:'Este horario ya estaba guardado.'});
        if (movement==='entrada') {
          requireState(!old.horaSalida && !old.salidaComidaReal && old.estatus!=='incapacidad_pagada','failed-precondition','La jornada requiere revisión de Administración.');
          Object.assign(patch,{trabajadorId:uid,fecha:old.fecha || stamp,horaEntrada:stamp,estatus:old.estatusJustificacion==='aprobada'?'justificado':arrival(actor,now),...location});
          if (!record.exists) Object.assign(patch,{horaSalida:null,salidaComidaSolicitada:null,salidaComidaReal:null,regresoComidaReal:null,estatusComida:'ninguna',estatusJustificacion:'ninguna',observacionesTrabajador:'',observacionesAdmin:'',historialModificaciones:[],listaBonos:[],listaMultas:[]});
          message='Entrada registrada.';
        } else {
          requireState(milliseconds(old.horaEntrada)!==null && !old.horaSalida,'failed-precondition','Primero registra tu entrada; la jornada debe seguir abierta.');
          requireState(milliseconds(old.horaEntrada)<=now.getTime(),'failed-precondition','La hora de entrada necesita revisión.');
          if (movement==='salida_comida') {
            requireState(!old.regresoComidaReal && !(old.pausasJornada || []).some(p=>!p.regreso),'failed-precondition','Cierra tu pausa antes de iniciar la comida.');
            Object.assign(patch,{salidaComidaReal:stamp,estatusComida:'comiendo',salidaComidaRegistradaPor:uid});message='Salida a comer registrada.';
          } else if (movement==='solicitar_comida') {
            requireState(!old.salidaComidaReal,'failed-precondition','La salida a comer ya está registrada.');
            Object.assign(patch,{salidaComidaSolicitada:stamp,estatusComida:'pendiente_aprobacion'});message='Solicitud de comida enviada.';
          } else if (movement==='regreso_comida') {
            const left=milliseconds(old.salidaComidaReal);
            requireState(left!==null && left<=now.getTime(),'failed-precondition','Primero registra la salida a comer.');
            Object.assign(patch,{regresoComidaReal:stamp,estatusComida:'finalizada',ubicacionRegresoComidaValida:!isManual});message='Regreso de comida registrado.';
          } else {
            requireState(!(old.pausasJornada || []).some(p=>!p.regreso),'failed-precondition','Registra tu regreso de la pausa antes de terminar.');
            requireState(!old.salidaComidaReal || old.regresoComidaReal,'failed-precondition','Registra tu regreso de comida antes de salir.');
            Object.assign(patch,{horaSalida:stamp});message='Salida de jornada registrada.';
          }
        }
      } else {
        requireState(milliseconds(old.horaEntrada)!==null && !old.horaSalida,'failed-precondition','La jornada debe estar abierta.');
        requireState(!old.salidaComidaReal || old.regresoComidaReal,'failed-precondition','Primero registra el regreso de comida.');
        const pauses=Array.isArray(old.pausasJornada)?old.pausasJornada.map(p=>({...p})):[];
        requireState(pauses.length<100,'resource-exhausted','Administración debe revisar las pausas de esta jornada.');
        if (data.direction==='out') {
          requireState(!pauses.some(p=>!p.regreso),'failed-precondition','Ya tienes una pausa abierta.');
          const kind=String(data.kind || 'otro'),detail=String(data.detail || '').trim();
          requireState(['baño','bano','sanitario','fuera','personal','trabajo','servicio','otro','descanso','medico'].includes(kind) && detail.length<=500,'invalid-argument','Revisa el tipo de pausa.');
          pauses.push({id:token,tipo:kind,descripcion:detail,salida:stamp,regreso:null,registradoPor:uid});
          message='Salida temporal registrada.';eventAction='pausa_salida';
        } else {
          requireState(data.direction==='in' && id(data.pauseId),'invalid-argument','Selecciona una pausa abierta.');
          const index=pauses.findIndex(p=>p.id===data.pauseId);
          requireState(index>=0,'not-found','No se encontró la pausa.');
          if (pauses[index].regreso) return receipt(target,day,old,actor,{yaRegistrada:true,mensaje:'El regreso ya estaba registrado.'});
          pauses[index].regreso=stamp;message='Regreso de pausa registrado.';eventAction='pausa_regreso';
        }
        patch.pausasJornada=pauses;
      }
    }
    patch.resumenJornada=ledgerSummary({...old,...patch});
    if (record.exists) tx.update(ref,patch); else tx.create(ref,patch);
    tx.create(op,{uid,target,action:eventAction,asistenciaId:ref.id,hash,fecha:stamp});
    tx.create(db.collection('empresa_auditoria').doc(`jornada_${uid}_${token}`),{tipo:'jornada',usuarioId:target,creadoPor:uid,asistenciaId:ref.id,accion:eventAction,manual:data.manual===true,fecha:stamp});
    tx.set(db.collection('notificaciones').doc(`jornada2026_${uid}_${token}`),{titulo:message,mensaje:'Consulta el registro y sus horarios en Mi jornada.',tipo:'asistencia_jornada',destinatarioId:target,rolesDestinatarios:['admin'],leidosPor:[],creadoPor:'sistema',fecha:stamp,asistenciaId:ref.id,accion:eventAction,ruta:'/asistencia'});
    return receipt(target,day,{...old,...patch},actor,{mensaje:message});
  });
}
const enterpriseAttendance=onCall({region:'us-central1',timeoutSeconds:30,maxInstances:5},request=>runEnterpriseAttendance({db:getFirestore(),uid:request.auth?.uid,data:request.data}));
module.exports={enterpriseAttendance,runEnterpriseAttendance,gpsAllowed,receipt};
