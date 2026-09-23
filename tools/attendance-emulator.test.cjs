'use strict';
// This test refuses to use any real company project or production endpoint.
const assert=require('node:assert/strict');const {test,after}=require('node:test');const {createRequire}=require('node:module');const path=require('node:path');
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'',/^(127\.0\.0\.1|localhost):\d+$/);
const load=createRequire(path.join(__dirname,'../functions/package.json'));
const {initializeApp,deleteApp}=load('firebase-admin/app');const {getFirestore,Timestamp}=load('firebase-admin/firestore');const {HttpsError}=load('firebase-functions/v2/https');
const app=initializeApp({projectId:'demo-sauna-attendance'});const db=getFirestore();
const {makeAttendanceHandler,ZONES}=require('../functions/attendance-ledger');const {reconcileAttendance}=require('../functions/attendance-functions');
after(async()=>{await db.terminate();await deleteApp(app);});
test('real Firestore transactions persist four steps and reconcile admin lunch/corrections without duplicates',async()=>{
 const uid='emulator-worker',day='20260923',ref=db.doc(`asistencias/${uid}_${day}`);
 await db.doc(`usuarios/${uid}`).set({nombre:'QA aislada',rol:'trabajador',activo:true,horaEntrada:'09:00',sueldoBaseSemanal:1234});
 let now=new Date('2026-09-23T15:00:00Z');const handle=makeAttendanceHandler({db,Timestamp,HttpsError,clock:()=>now});
 const request=accion=>({auth:{uid},data:{accion,latitud:ZONES[0].lat,longitud:ZONES[0].lon}});
 const first=await Promise.all(Array.from({length:8},()=>handle(request('entrada'))));
 assert.equal(first.filter(r=>r.yaRegistrada!==true).length,1);
 assert.equal((await db.collection('notificaciones').get()).size,1);
 now=new Date('2026-09-23T21:00:00Z');await handle(request('solicitar_comida'));
 const before=await ref.get();await ref.update({estatusComida:'comiendo',salidaComidaReal:Timestamp.fromDate(new Date('2026-09-23T21:05:00Z'))});const afterApproval=await ref.get();
 const event={id:'approval-event-1',params:{attendanceId:ref.id},data:{before,after:afterApproval}};
 await reconcileAttendance.run(event);await reconcileAttendance.run(event);
 assert.equal((await db.collection('notificaciones').get()).size,3);
 now=new Date('2026-09-23T21:35:00Z');await handle(request('regreso_comida'));
 now=new Date('2026-09-24T01:00:00Z');await handle(request('salida'));
 let saved=await ref.get();assert.equal(saved.data().resumenJornada.minutosEntreEntradaYSalida,600);assert.equal(saved.data().resumenJornada.minutosComida,30);
 // Replaying an old approval must not overwrite the complete current summary.
 await reconcileAttendance.run(event);assert.equal((await ref.get()).data().resumenJornada.minutosEntreEntradaYSalida,600);
 const previous=saved;await ref.update({horaSalida:Timestamp.fromDate(new Date('2026-09-24T01:30:00Z'))});saved=await ref.get();
 await reconcileAttendance.run({id:'correction-event-1',params:{attendanceId:ref.id},data:{before:previous,after:saved}});
 assert.equal((await ref.get()).data().resumenJornada.minutosEntreEntradaYSalida,630);
 assert.equal((await db.collection('notificaciones').get()).size,6);
 const source=await db.collection('asistencias').where('trabajadorId','==',uid).where('fecha','>=',Timestamp.fromDate(new Date('2026-09-23T06:00:00Z'))).where('fecha','<',Timestamp.fromDate(new Date('2026-09-24T06:00:00Z'))).get();
 assert.equal(source.size,1);for(const field of ['horaEntrada','horaSalida','salidaComidaReal','regresoComidaReal'])assert.equal(typeof source.docs[0].get(field).toMillis,'function');
 assert.equal((await db.doc(`usuarios/${uid}`).get()).data().sueldoBaseSemanal,1234);
 assert.equal((await db.collection('nomina').get()).size,0);
});
