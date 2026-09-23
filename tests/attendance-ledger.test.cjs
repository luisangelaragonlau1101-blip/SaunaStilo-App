'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {makeAttendanceHandler,ledgerSummary,changedTimes,dateKey,ZONES}=require('../functions/attendance-ledger');
class Stamp{constructor(ms){this.ms=ms;}toMillis(){return this.ms;}static fromDate(d){return new Stamp(d.getTime());}}
class Fault extends Error{constructor(code,message){super(message);this.code=code;}}
function harness(){
  const store=new Map(), writes=[];
  const db={collection:name=>({doc:id=>({id,path:`${name}/${id}`})}),runTransaction:async callback=>{
    const pending=[];let beganWrite=false;
    const tx={get:async ref=>{assert.equal(beganWrite,false,'No reads after writes');const v=store.get(ref.path);return{exists:v!==undefined,id:ref.id,data:()=>v};},set:(r,d)=>{beganWrite=true;pending.push(['set',r,d]);},update:(r,d)=>{beganWrite=true;pending.push(['update',r,d]);},create:(r,d)=>{beganWrite=true;pending.push(['create',r,d]);}};
    const value=await callback(tx);
    for(const[k,r]of pending){if(k==='create')assert.equal(store.has(r.path),false);if(k==='update')assert.equal(store.has(r.path),true);}
    for(const[k,r,d]of pending){store.set(r.path,k==='update'?{...store.get(r.path),...d}:d);writes.push(r.path);}
    return value;
  }};
  store.set('usuarios/u',{nombre:'Persona de prueba',rol:'trabajador',activo:true,horaEntrada:'09:00',toleranciaMinutos:11,sueldoBaseSemanal:3000});
  let now=new Date('2026-09-23T15:00:00Z');
  const call=makeAttendanceHandler({db,Timestamp:Stamp,HttpsError:Fault,clock:()=>now});
  const request=(accion,overrides={})=>({auth:{uid:'u'},data:{accion,latitud:ZONES[0].lat,longitud:ZONES[0].lon,...overrides}});
  const ref='asistencias/u_20260923';
  return{store,writes,db,request,call,ref,time:iso=>{now=new Date(iso);},data:()=>store.get(ref),notes:()=>[...store.entries()].filter(([k])=>k.startsWith('notificaciones/'))};
}
async function rejects(code,fn){await assert.rejects(fn,e=>e instanceof Fault&&e.code===code);}
test('Mexico midnight is independent of UTC or the phone timezone',()=>{assert.equal(dateKey(new Date('2026-09-24T05:59:59Z')),'20260923');assert.equal(dateKey(new Date('2026-09-24T06:00:00Z')),'20260924');});
test('entry, approved lunch, return and exit share one ledger consumed by attendance/payroll',async()=>{
 const h=harness();await h.call(h.request('entrada'));
 h.time('2026-09-23T21:00:00Z');await h.call(h.request('solicitar_comida'));
 assert.equal(h.data().estatusComida,'pendiente_aprobacion');assert.equal(h.data().salidaComidaReal,null);
 h.store.set(h.ref,{...h.data(),estatusComida:'comiendo',salidaComidaReal:Stamp.fromDate(new Date('2026-09-23T21:05:00Z'))});
 h.time('2026-09-23T21:35:00Z');await h.call(h.request('regreso_comida'));
 h.time('2026-09-24T01:00:00Z');const out=await h.call(h.request('salida'));
 assert.equal(out.exito,true);assert.match(out.mensaje,/Felicidades/);
 assert.equal([...h.store.keys()].filter(k=>k.startsWith('asistencias/')).length,1);
 assert.deepEqual(h.data().resumenJornada,{version:1,minutosEntreEntradaYSalida:600,minutosComida:30,minutosSinComida:570,requiereRevision:false,incidencias:[],soloInformativo:true});
 assert.equal(h.notes().length,4);
 for(const[,n]of h.notes()){assert.equal(n.destinatarioId,'u');assert.deepEqual(n.rolesDestinatarios,['admin']);assert.equal(n.asistenciaId,'u_20260923');}
 assert.equal(h.store.get('usuarios/u').sueldoBaseSemanal,3000);
 assert.ok(!h.writes.some(p=>p.startsWith('nomina')));
});
test('lost-response retries preserve entry/request/return/exit and do not notify twice',async()=>{
 const h=harness();for(const action of ['entrada','solicitar_comida']){await h.call(h.request(action));const n=h.notes().length;const previous={...h.data()};assert.equal((await h.call(h.request(action))).yaRegistrada,true);assert.equal(h.notes().length,n);assert.deepEqual(h.data(),previous);}
 h.store.set(h.ref,{...h.data(),estatusComida:'comiendo',salidaComidaReal:Stamp.fromDate(new Date('2026-09-23T15:01:00Z'))});h.time('2026-09-23T15:31:00Z');await h.call(h.request('regreso_comida'));await h.call(h.request('regreso_comida'));
 h.time('2026-09-23T23:00:00Z');await h.call(h.request('salida'));const before=h.data().horaSalida;await h.call(h.request('salida'));assert.equal(h.data().horaSalida,before);assert.equal(h.notes().length,4);
});
test('unauthenticated, inactive, unknown-role and administrator accounts cannot clock in',async()=>{
 for(const mode of ['anonymous','admin','inactive','unknown']){const h=harness();const r=h.request('entrada');if(mode==='anonymous')delete r.auth;else h.store.set('usuarios/u',{...h.store.get('usuarios/u'),...(mode==='inactive'?{activo:false}:{rol:mode==='admin'?'admin':'visitor'})});await rejects(mode==='anonymous'?'unauthenticated':'permission-denied',()=>h.call(r));assert.equal(h.writes.length,0);}
});
test('maestro and almacenista can register their own attendance',async()=>{for(const rol of ['maestro','almacenista']){const h=harness();h.store.set('usuarios/u',{...h.store.get('usuarios/u'),rol});assert.equal((await h.call(h.request('entrada'))).exito,true);}});
test('changing a worker id cannot clock in for another person',async()=>{const h=harness();await rejects('permission-denied',()=>h.call(h.request('entrada',{trabajadorId:'other'})));assert.equal(h.writes.length,0);});
test('GPS null strings nonfinite out of bounds or outside the site are rejected',async()=>{for(const latitud of [null,'19.26247565075755',NaN,Infinity,91,0]){const h=harness();await rejects('failed-precondition',()=>h.call(h.request('entrada',{latitud})));assert.equal(h.writes.length,0);}});
test('out of order actions write neither a time nor a notification',async()=>{for(const a of ['salida','solicitar_comida','regreso_comida']){const h=harness();await rejects('failed-precondition',()=>h.call(h.request(a)));assert.equal(h.writes.length,0);}});
test('a pending lunch request is not a recorded meal departure',async()=>{const h=harness();await h.call(h.request('entrada'));await h.call(h.request('solicitar_comida'));const before=h.notes().length;await rejects('failed-precondition',()=>h.call(h.request('regreso_comida')));assert.equal(h.data().regresoComidaReal,null);assert.equal(h.notes().length,before);});
test('approved justifications, bonuses, notes and manual adjustments survive entry',async()=>{const h=harness();h.store.set(h.ref,{trabajadorId:'u',fecha:Stamp.fromDate(new Date('2026-09-23T13:00:00Z')),estatus:'justificado',estatusJustificacion:'aprobada',motivoFalta:'Revisado',listaBonos:[{monto:100,motivo:'Reconocimiento'}],listaMultas:[],observacionesAdmin:'Conservar',historialModificaciones:['Autorizado']});await h.call(h.request('entrada'));assert.equal(h.data().estatus,'justificado');assert.equal(h.data().observacionesAdmin,'Conservar');assert.deepEqual(h.data().listaBonos,[{monto:100,motivo:'Reconocimiento'}]);assert.deepEqual(h.data().historialModificaciones,['Autorizado']);});
test('no automatic exit and no automatic meal-duration or wage penalty',async()=>{const h=harness();await h.call(h.request('entrada'));h.time('2026-09-24T01:00:00Z');assert.equal(h.data().horaSalida,null);assert.equal(h.data().resumenJornada.minutosEntreEntradaYSalida,null);assert.ok(h.data().resumenJornada.requiereRevision);});
test('exit with missing lunch return is recorded but flagged for review, never invented',async()=>{const h=harness();await h.call(h.request('entrada'));h.store.set(h.ref,{...h.data(),estatusComida:'comiendo',salidaComidaReal:Stamp.fromDate(new Date('2026-09-23T21:00:00Z'))});h.time('2026-09-24T01:00:00Z');const result=await h.call(h.request('salida'));assert.equal(result.exito,true);assert.equal(h.data().regresoComidaReal,null);assert.ok(h.data().resumenJornada.incidencias.includes('comida_sin_regreso'));assert.equal(h.data().resumenJornada.minutosSinComida,null);});
test('closed days cannot request or return from lunch',async()=>{const h=harness();await h.call(h.request('entrada'));await h.call(h.request('salida'));await rejects('failed-precondition',()=>h.call(h.request('solicitar_comida')));await rejects('failed-precondition',()=>h.call(h.request('regreso_comida')));});
test('admin correction changes the next derived summary without changing money',()=>{const d={horaEntrada:new Stamp(10000000),horaSalida:new Stamp(13600000),salidaComidaReal:new Stamp(11000000),regresoComidaReal:new Stamp(11600000),listaBonos:[{monto:123}]};const before=ledgerSummary(d);assert.equal(before.minutosComida,10);const after={...d,horaSalida:new Stamp(17200000)};assert.equal(ledgerSummary(after).minutosEntreEntradaYSalida,120);assert.deepEqual(changedTimes(d,after),['horaSalida']);assert.deepEqual(after.listaBonos,d.listaBonos);});
test('negative or out-of-shift meal times are review issues, not paid hours',()=>{const s=ledgerSummary({horaEntrada:new Stamp(10000000),horaSalida:new Stamp(9000000),salidaComidaReal:new Stamp(11000000),regresoComidaReal:new Stamp(10000000)});assert.equal(s.minutosSinComida,null);assert.equal(s.minutosEntreEntradaYSalida,null);assert.ok(s.requiereRevision);});
test('an existing notification does not prevent a repaired day from saving',async()=>{const h=harness();h.store.set('notificaciones/jornada_u_20260923_entrada',{preserved:true});assert.equal((await h.call(h.request('entrada'))).exito,true);assert.equal(h.notes().length,1);assert.equal(h.notes()[0][1].preserved,true);});
test('invalid actions and future stored entry times fail closed',async()=>{const h=harness();await rejects('invalid-argument',()=>h.call(h.request('approve_everyone')));h.store.set(h.ref,{trabajadorId:'u',horaEntrada:new Stamp(new Date('2026-09-25T15:00:00Z').getTime())});await rejects('failed-precondition',()=>h.call(h.request('salida')));});
