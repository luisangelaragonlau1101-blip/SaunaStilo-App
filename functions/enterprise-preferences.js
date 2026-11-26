'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp, FieldPath} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');
const {PERMISSIONS, requireProfile, active} = require('./enterprise-access');

function birthdayValue(input) {
  if (input == null) return null;
  if (typeof input !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input)) throw new HttpsError('invalid-argument','Revisa tu fecha de cumpleaños.');
  const value = new Date(input + 'T12:00:00Z');
  if (!Number.isFinite(value.getTime()) || value.toISOString().slice(0,10) !== input || value.getUTCFullYear() < 1900 || value > new Date()) throw new HttpsError('invalid-argument','Revisa tu fecha de cumpleaños.');
  return value;
}
function dateString(value) {
  const date = value instanceof Date ? value : value && typeof value.toDate === 'function' ? value.toDate() : null;
  return date && Number.isFinite(date.getTime()) ? date.toISOString().slice(0,10) : null;
}
async function runPreferences({db,uid,data = {}}) {
  const actor = await requireProfile(db,uid,HttpsError);
  const own = db.collection('preferencias_personales').doc(uid);
  if (data.action === 'readBirthday') {
    const snapshot = await own.get(), p = snapshot.data() || {};
    return {birthday:dateString(p.cumpleanos ?? actor.cumpleanos),visibility:p.visibilidadCumpleanos || 'privado',greetings:p.felicitarCumpleanos === true};
  }
  if (data.action === 'saveBirthday') {
    const birthday = birthdayValue(data.birthday);
    if (!['privado','equipo','administracion'].includes(data.visibility) || typeof data.greetings !== 'boolean') throw new HttpsError('invalid-argument','Elige quién puede ver tu cumpleaños.');
    await db.runTransaction(async tx=>{
      const userRef = db.collection('usuarios').doc(uid);
      const [profile, prior] = await Promise.all([tx.get(userRef),tx.get(own)]);
      if (!profile.exists || !active(profile.data())) throw new HttpsError('permission-denied','Tu cuenta no está activa.');
      tx.set(own,{cumpleanos:birthday ? Timestamp.fromDate(birthday) : null,visibilidadCumpleanos:data.visibility,felicitarCumpleanos:data.greetings,actualizadoEn:FieldValue.serverTimestamp(),...(prior.exists || !profile.data().cumpleanos ? {} : {cumpleanosHistorico:profile.data().cumpleanos})}, {merge:true});
      tx.update(userRef,{cumpleanos:FieldValue.delete()});
      const projection = db.collection('cumpleanos_equipo').doc(uid);
      if (birthday && data.visibility === 'equipo') tx.set(projection,{nombre:String(profile.data().nombre || '').slice(0,160),fotoUrl:String(profile.data().fotoUrl || '').startsWith('https:') ? String(profile.data().fotoUrl).slice(0,2048) : '',month:birthday.getUTCMonth()+1,day:birthday.getUTCDate(),activo:true,felicitar:data.greetings});
      else tx.delete(projection);
    });
    return {ok:true,birthday:dateString(birthday),visibility:data.visibility,greetings:data.greetings};
  }
  if (data.action === 'birthdays') {
    const projection = await db.collection('cumpleanos_equipo').get();
    const people = new Map(projection.docs.filter(d=>d.data().activo !== false).map(d=>[d.id,{id:d.id,...d.data()}]));
    const p = (await own.get()).data() || {};
    const birth = dateString(p.cumpleanos ?? actor.cumpleanos);
    if (birth) { const d=new Date(birth+'T12:00:00Z'); people.set(uid,{id:uid,nombre:actor.nombre || '',month:d.getUTCMonth()+1,day:d.getUTCDate(),own:true}); }
    if (actor.rol === 'admin') {
      const privateBirthdays = await db.collection('preferencias_personales').where('visibilidadCumpleanos','==','administracion').get();
      for (const pref of privateBirthdays.docs) {
        const b = dateString(pref.data().cumpleanos);
        if (!b) continue;
        const profile = await db.collection('usuarios').doc(pref.id).get();
        if (!profile.exists || !active(profile.data())) continue;
        const d = new Date(b+'T12:00:00Z'); people.set(pref.id,{id:pref.id,nombre:profile.data().nombre || '',month:d.getUTCMonth()+1,day:d.getUTCDate(),administrationOnly:true});
      }
    }
    return {items:[...people.values()]};
  }
  if (data.action === 'migrateBirthdayPrivacy') {
    if (actor.rol !== 'admin') throw new HttpsError('permission-denied','Solo Administración puede migrar el calendario.');
    let query = db.collection('usuarios').orderBy(FieldPath.documentId()).limit(100);
    if (data.cursor) {
      if (typeof data.cursor !== 'string' || data.cursor.includes('/')) throw new HttpsError('invalid-argument','Cursor inválido.');
      query = query.startAfter(data.cursor);
    }
    const rows = await query.get(); let migrated=0;
    for (const doc of rows.docs) {
      if (!doc.data().cumpleanos) continue;
      await db.runTransaction(async tx=>{
        const ref=db.collection('preferencias_personales').doc(doc.id);
        const [fresh,pref] = await Promise.all([tx.get(doc.ref),tx.get(ref)]);
        if (!fresh.exists || !fresh.data().cumpleanos) return;
        const prior=pref.data() || {};
        tx.set(ref,{...(Object.hasOwn(prior,'cumpleanos') ? {} : {cumpleanos:fresh.data().cumpleanos}),cumpleanosHistorico:fresh.data().cumpleanos,visibilidadCumpleanos:prior.visibilidadCumpleanos || 'privado',felicitarCumpleanos:prior.felicitarCumpleanos === true,migradoEn:FieldValue.serverTimestamp()}, {merge:true});
        tx.update(doc.ref,{cumpleanos:FieldValue.delete()});
        migrated++;
      });
    }
    return {ok:true,migrated,nextCursor:rows.size === 100 ? rows.docs.at(-1).id : null};
  }
  throw new HttpsError('invalid-argument','Preferencia no reconocida.');
}
const enterprisePreferences = onCall({region:'us-central1',timeoutSeconds:120,maxInstances:3},request=>runPreferences({db:getFirestore(),uid:request.auth?.uid,data:request.data}));

async function runAccess({db,uid,data={}}) {
  const actor = await requireProfile(db,uid,HttpsError);
  if (actor.rol !== 'admin') throw new HttpsError('permission-denied','Solo Administración configura permisos.');
  if (data.action === 'list') {
    const rows=await db.collection('usuarios').get();
    return {items:rows.docs.map(d=>({id:d.id,nombre:String(d.data().nombre || ''),rol:String(d.data().rol || ''),activo:d.data().activo!==false,permisosEmpresa:Array.isArray(d.data().permisosEmpresa)?d.data().permisosEmpresa.filter(k=>PERMISSIONS.includes(k)):[],asistenciaManualPermitida:d.data().asistenciaManualPermitida===true,horaComida:d.data().horaComida||'15:00',minutosComida:d.data().minutosComida||70}))};
  }
  if (data.action !== 'save' || typeof data.userId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(data.userId) || !Array.isArray(data.permissions) || !data.permissions.every(k=>PERMISSIONS.includes(k)) || !/^[A-Za-z0-9_-]{8,128}$/.test(data.operationId || '')) throw new HttpsError('invalid-argument','Revisa la cuenta y sus permisos.');
  const permissions=[...new Set(data.permissions)].sort();
  const patch={permisosEmpresa:permissions};
  if (typeof data.manualAttendance === 'boolean') patch.asistenciaManualPermitida=data.manualAttendance;
  if (data.lunchTime != null) {
    if (!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(data.lunchTime)) throw new HttpsError('invalid-argument','Revisa la hora de comida.');
    patch.horaComida=data.lunchTime;
  }
  if (data.lunchMinutes != null) {
    if (!Number.isInteger(data.lunchMinutes) || data.lunchMinutes<10 || data.lunchMinutes>180) throw new HttpsError('invalid-argument','Revisa la duración de comida.');
    patch.minutosComida=data.lunchMinutes;
  }
  const digest=createHash('sha256').update(JSON.stringify([data.userId,patch])).digest('hex');
  const audit=db.collection('empresa_auditoria').doc(`permisos_${uid}_${data.operationId}`);
  await db.runTransaction(async tx=>{
    const target=db.collection('usuarios').doc(data.userId);
    const [current,prior,author]=await Promise.all([tx.get(target),tx.get(audit),tx.get(db.collection('usuarios').doc(uid))]);
    if (!author.exists || !active(author.data()) || author.data().rol !== 'admin') throw new HttpsError('permission-denied','Tu autorización cambió.');
    if (!current.exists) throw new HttpsError('not-found','La cuenta ya no existe.');
    if (prior.exists) {
      if (prior.data().hash !== digest) throw new HttpsError('already-exists','La solicitud ya guardó otros permisos.');
      return;
    }
    tx.update(target,{...patch,permisosActualizadosPor:uid,permisosActualizadosEn:FieldValue.serverTimestamp()});
    tx.create(audit,{tipo:'permisos',usuarioId:data.userId,antes:current.data().permisosEmpresa || [],despues:permissions,configuracion:patch,creadoPor:uid,fecha:FieldValue.serverTimestamp(),hash:digest});
  });
  return {ok:true};
}
const enterpriseAccess=onCall({region:'us-central1',timeoutSeconds:30,maxInstances:3},request=>runAccess({db:getFirestore(),uid:request.auth?.uid,data:request.data}));
module.exports = {enterprisePreferences,enterpriseAccess,runPreferences,runAccess,birthdayValue};
