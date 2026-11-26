'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');
const {canAssignProjectTask, validateTaskInput, remindersDue} = require('./team-operations-policy');

const assignProjectActivity = onCall({region:'us-central1',timeoutSeconds:30,maxInstances:5}, async request => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated','Debes iniciar sesión.');
  let input;
  try { input = validateTaskInput(request.data); } catch (_) { throw new HttpsError('invalid-argument','Revisa proyecto, integrante, actividad y fecha de entrega.'); }
  const db = getFirestore();
  const taskRef = db.collection('actividades').doc(`equipo_${uid}_${input.requestId}`);
  const fingerprint = createHash('sha256').update(JSON.stringify(input)).digest('hex');
  return db.runTransaction(async transaction => {
    const caller = await transaction.get(db.collection('usuarios').doc(uid));
    const target = await transaction.get(db.collection('usuarios').doc(input.trabajadorId));
    const projectRef = db.collection('proyectos').doc(input.proyectoId);
    const project = await transaction.get(projectRef);
    const existing = await transaction.get(taskRef);
    const rateRef = db.collection('_team_operation_limits').doc(uid);
    const rate = await transaction.get(rateRef);
    if (!caller.exists || !target.exists || !project.exists || !canAssignProjectTask({uid, targetId:input.trabajadorId,caller:caller.data(),target:target.data(),project:project.data()})) throw new HttpsError('permission-denied','Solo administración o un maestro del proyecto pueden asignar actividades a sus integrantes.');
    if (existing.exists) {
      if (existing.data().creadoPor !== uid || existing.data().solicitudHash !== fingerprint) throw new HttpsError('already-exists','Esta solicitud ya guardó una actividad diferente. Revisa el proyecto.');
      return {exito:true, actividadId:taskRef.id, yaRegistrada:true};
    }
    const minute = Math.floor(Date.now()/60000);
    const prior = rate.data() || {};
    const count = prior.minute === minute ? Number(prior.count || 0) : 0;
    if (count >= 20) throw new HttpsError('resource-exhausted','Se alcanzó el límite temporal de asignaciones.');
    transaction.set(taskRef, {
      proyectoId:input.proyectoId,titulo:input.titulo,descripcion:input.descripcion,
      asignadoATrabajadorId:input.trabajadorId,fechaInicio:FieldValue.serverTimestamp(),fechaAsignada:FieldValue.serverTimestamp(),
      fechaTermino:Timestamp.fromDate(new Date(input.fechaTermino)),completadoEn:null,estatus:'pendiente',
      observacionesAdmin:'',comentariosTrabajador:'',evidenciaFotos:[],historialEventos:[],evidenciasCount:0,cantidadEvidencias:0,requiereEvidencia:true,
      creadoPor:uid,creadorRol:caller.data().rol,solicitudHash:fingerprint,
    });
    transaction.set(rateRef,{minute,count:count+1});
    transaction.set(db.collection('notificaciones').doc(`tarea_${taskRef.id}`),{
      titulo:'Nueva actividad asignada',mensaje:'Abre tus tareas para consultar las indicaciones y la fecha de entrega.',tipo:'tarea',destinatarioId:input.trabajadorId,rolesDestinatarios:[],leidosPor:[],creadoPor:uid,fecha:FieldValue.serverTimestamp(),proyectoId:input.proyectoId,actividadId:taskRef.id,ruta:'/proyectos',
    });
    return {exito:true,actividadId:taskRef.id};
  });
});

const repeatWorkdayReminders = onSchedule({region:'us-central1',schedule:'*/5 * * * *',timeZone:'America/Mexico_City',timeoutSeconds:120,maxInstances:1}, async () => {
  const {runWorkdayReminders,runBirthdayNotices}=require('./enterprise-notifications');
  const db=getFirestore(),now=new Date();
  await runWorkdayReminders(db,now);
  await runBirthdayNotices(db,now);
});

module.exports = {assignProjectActivity,repeatWorkdayReminders};
