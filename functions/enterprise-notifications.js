'use strict';
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {getFirestore,FieldValue} = require('firebase-admin/firestore');
const {workdayReminders,reminderCompleted,localParts} = require('./enterprise-notification-policy');
const {active} = require('./enterprise-access');

async function runWorkdayReminders(db,now=new Date(),actions=null) {
  const users=await db.collection('usuarios').get();
  const parts=localParts(now),day=parts.year+parts.month+parts.day;
  let created=0;
  for (let start=0;start<users.size;start+=15) {
    await Promise.all(users.docs.slice(start,start+15).map(async user=>{
      if (!active(user.data()) || !['trabajador','maestro','almacenista'].includes(user.data().rol)) return;
      const attendance=db.collection('asistencias').doc(`${user.id}_${day}`);
      const pref=db.collection('preferencias_notificaciones').doc(user.id);
      const [record,preferences]=await Promise.all([attendance.get(),pref.get()]);
      const candidates=workdayReminders(user.data(),record.data(),now,preferences.data());
      for (const event of candidates) {
        if (actions && !actions.includes(event.action)) continue;
        const note=db.collection('notificaciones').doc(`recordatorio2026_${day}_${event.action}_${user.id}`);
        await db.runTransaction(async tx=>{
          const [freshProfile,freshAttendance,freshPreferences,existing]=await Promise.all([tx.get(user.ref),tx.get(attendance),tx.get(pref),tx.get(note)]);
          if (existing.exists || !freshProfile.exists) return;
          if (!workdayReminders(freshProfile.data(),freshAttendance.data(),now,freshPreferences.data()).some(item=>item.action===event.action)) return;
          tx.create(note,{titulo:event.title,mensaje:event.body,tipo:`asistencia_${event.action}`,destinatarioId:user.id,rolesDestinatarios:[],leidosPor:[],creadoPor:'sistema',fecha:FieldValue.serverTimestamp(),ruta:'/asistencia',asistenciaId:attendance.id,recordatorio:true,accion:event.action});
          created++;
        });
      }
    }));
  }
  return {created};
}

const cancelAttendanceReminders=onDocumentWritten({document:'asistencias/{attendanceId}',region:'us-central1',retry:true,maxInstances:3},async event=>{
  if (!event.data?.after.exists) return;
  const data=event.data.after.data(),uid=data.trabajadorId;
  if (typeof uid!=='string' || !uid || uid.includes('/')) return;
  const match=new RegExp(`^${uid.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}_(\\d{8})$`).exec(event.params.attendanceId);
  if (!match) return;
  const db=getFirestore(),day=match[1],batch=db.batch(); let changed=0;
  for (const action of ['entrada','comida','regreso_comida','salida']) {
    if (!reminderCompleted(action,data)) continue;
    const ids=[`recordatorio2026_${day}_${action}_${uid}`];
    for (let slot=0;slot<4;slot++) {
      ids.push(`jornada_${action}_${day}_${uid}_${slot}`,`recordatorio_${day}_${action}_${slot}_${uid}`);
    }
    const docs=await db.getAll(...ids.map(id=>db.collection('notificaciones').doc(id)));
    for (const note of docs) if (note.exists && note.data().cancelada!==true) {batch.update(note.ref,{cancelada:true,canceladaEn:FieldValue.serverTimestamp()});changed++;}
  }
  if (changed) await batch.commit();
});

async function runBirthdayNotices(db,now=new Date()) {
  const p=localParts(now);
  // One daily pass during the first hour of the workday; no startup work.
  if (+p.hour!==9) return {created:0};
  const shared=await db.collection('cumpleanos_equipo').where('month','==',+p.month).where('day','==',+p.day).get();
  const day=p.year+p.month+p.day; let created=0;
  for (const person of shared.docs) {
    if (person.data().felicitar!==true || person.data().activo===false) continue;
    const note=db.collection('notificaciones').doc(`cumpleanos_${day}_${person.id}`);
    await db.runTransaction(async tx=>{
      const [existing,profile,privatePref]=await Promise.all([tx.get(note),tx.get(db.collection('usuarios').doc(person.id)),tx.get(db.collection('preferencias_personales').doc(person.id))]);
      if (existing.exists || !profile.exists || !active(profile.data()) || privatePref.data()?.visibilidadCumpleanos!=='equipo' || privatePref.data()?.felicitarCumpleanos!==true) return;
      tx.create(note,{titulo:'🎂 Hoy celebramos un cumpleaños',mensaje:`¡Feliz cumpleaños, ${String(profile.data().nombre || 'integrante').slice(0,120)}!`,tipo:'cumpleanos',destinatarioId:'todos',rolesDestinatarios:['todos'],leidosPor:[],creadoPor:'sistema',fecha:FieldValue.serverTimestamp(),ruta:'/cumpleanos',usuarioCelebradoId:person.id});
      created++;
    });
  }
  return {created};
}

const syncBirthdayProjection=onDocumentWritten({document:'usuarios/{userId}',region:'us-central1',retry:true,maxInstances:3},async event=>{
  const uid=event.params.userId,db=getFirestore();
  await db.runTransaction(async tx=>{
    const [user,pref]=await Promise.all([tx.get(db.collection('usuarios').doc(uid)),tx.get(db.collection('preferencias_personales').doc(uid))]);
    const projection=db.collection('cumpleanos_equipo').doc(uid),data=pref.data() || {};
    if (!user.exists || !active(user.data()) || data.visibilidadCumpleanos!=='equipo' || !data.cumpleanos?.toDate) {tx.delete(projection);return;}
    const birth=data.cumpleanos.toDate(),profile=user.data();
    tx.set(projection,{nombre:String(profile.nombre || '').slice(0,160),fotoUrl:String(profile.fotoUrl || '').startsWith('https:')?String(profile.fotoUrl).slice(0,2048):'',month:birth.getUTCMonth()+1,day:birth.getUTCDate(),activo:true,felicitar:data.felicitarCumpleanos===true});
  });
});
module.exports={runWorkdayReminders,runBirthdayNotices,cancelAttendanceReminders,syncBirthdayProjection};
