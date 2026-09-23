'use strict';
const {onCall}=require('firebase-functions/v2/https');
const {onDocumentWritten}=require('firebase-functions/v2/firestore');
const {HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const {makeAttendanceHandler,ledgerSummary,changedTimes,milliseconds}=require('./attendance-ledger');

// Same callable name and request/response format as the APK already installed.
const updateAttendance=onCall({region:'us-central1',timeoutSeconds:30,maxInstances:3},request=>makeAttendanceHandler({db:getFirestore(),Timestamp,HttpsError})(request));

// The current Administration screen approves lunch and corrects hours directly.
// Observe that same record; do not make a separate attendance or payroll database.
const reconcileAttendance=onDocumentWritten({document:'asistencias/{attendanceId}',region:'us-central1',retry:true,maxInstances:3},async event=>{
  if(!event.data?.after.exists)return;
  const before=event.data.before.exists?event.data.before.data():{},after=event.data.after.data();
  if(changedTimes(before,after).length===0&&before.estatusComida===after.estatusComida)return;
  const db=getFirestore(),ref=event.data.after.ref;
  const eventDigest=createHash('sha256').update(String(event.id)).digest('hex').slice(0,32);
  const noteRef=db.collection('notificaciones').doc(`jornada_revision_${eventDigest}`);
  await db.runTransaction(async tx=>{
    // Use the latest ledger for summaries: triggers can arrive out of order.
    const current=await tx.get(ref);
    if(!current.exists)return;
    const d=current.data(),uid=d.trabajadorId;
    if(typeof uid!=='string'||!uid||uid.includes('/'))return;
    const notification=await tx.get(noteRef);
    const summary=ledgerSummary(d);
    if(JSON.stringify(d.resumenJornada)!==JSON.stringify(summary)) tx.update(ref,{resumenJornada:summary});
    // Four worker actions generate an atomic notification in the callable.
    // This hook notifies only administration-origin lunch authorizations/time corrections.
    const approval=milliseconds(before.salidaComidaReal)===null&&milliseconds(after.salidaComidaReal)!==null;
    const corrections=changedTimes(before,after).filter(k=>milliseconds(before[k])!==null);
    if(!approval&&!corrections.length)return;
    if(notification.exists)return;
    tx.create(noteRef,{titulo:approval?'Comida autorizada':'Horario corregido por Administración',mensaje:approval?'Administración autorizó tu salida a comer. Recuerda registrar el regreso.':'Administración actualizó un horario. Revisa el mismo registro en Asistencias antes de revisar tu nómina.',tipo:'asistencia_jornada',destinatarioId:uid,rolesDestinatarios:['admin'],leidosPor:[],creadoPor:'sistema',fecha:Timestamp.now(),asistenciaId:ref.id,accion:approval?'comida_autorizada':'horario_corregido',ruta:'/asistencia'});
  });
});
module.exports={updateAttendance,reconcileAttendance};
