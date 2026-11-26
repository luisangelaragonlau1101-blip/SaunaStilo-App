const test=require('node:test'),assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const r=createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=r('firebase-admin/app');
const {getFirestore,Timestamp}=r('firebase-admin/firestore');
const {runPreferences,runAccess}=require('../functions/enterprise-preferences');
const {runWorkdayReminders}=require('../functions/enterprise-notifications');
let app,db;
test.before(async()=>{
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST,'Isolated emulator required');
  app=initializeApp({projectId:'demo-sauna-preferences-2026'});db=getFirestore(app);
  await db.collection('usuarios').doc('admin').set({rol:'admin',activo:true});
  await db.collection('usuarios').doc('worker').set({rol:'trabajador',activo:true,nombre:'Persona de prueba',cumpleanos:Timestamp.fromDate(new Date('2000-11-25T12:00:00Z'))});
  await db.collection('usuarios').doc('other').set({rol:'trabajador',activo:true});
});
test.after(async()=>deleteApp(app));
test('birthday migration retains the historical value privately and requires explicit consent to publish day and month',async()=>{
  await assert.rejects(runPreferences({db,uid:'worker',data:{action:'migrateBirthdayPrivacy'}}));
  await runPreferences({db,uid:'admin',data:{action:'migrateBirthdayPrivacy'}});
  assert.equal((await db.collection('usuarios').doc('worker').get()).data().cumpleanos,undefined);
  const historical=(await db.collection('preferencias_personales').doc('worker').get()).data();
  assert.equal(historical.cumpleanosHistorico.toDate().getUTCFullYear(),2000);
  assert.equal((await runPreferences({db,uid:'other',data:{action:'birthdays'}})).items.length,0);
  await runPreferences({db,uid:'worker',data:{action:'saveBirthday',birthday:'2000-11-25',visibility:'equipo',greetings:true}});
  const shared=(await runPreferences({db,uid:'other',data:{action:'birthdays'}})).items;
  assert.equal(shared[0].month,11);assert.equal(shared[0].day,25);assert.equal(shared[0].cumpleanos,undefined);
  await runPreferences({db,uid:'worker',data:{action:'saveBirthday',birthday:'2000-11-25',visibility:'privado',greetings:false}});
  assert.equal((await db.collection('cumpleanos_equipo').get()).size,0);
});
test('capabilities are configurable only by an active administrator and operation retries cannot overwrite a different grant',async()=>{
  const data={action:'save',userId:'worker',permissions:['solicitarCompras'],manualAttendance:true,operationId:'grant_once'};
  await assert.rejects(runAccess({db,uid:'worker',data}));
  await runAccess({db,uid:'admin',data});
  await runAccess({db,uid:'admin',data});
  await assert.rejects(runAccess({db,uid:'admin',data:{...data,permissions:['finanzas']}}));
  assert.deepEqual((await db.collection('usuarios').doc('worker').get()).data().permisosEmpresa,['solicitarCompras']);
});
test('server reminders deduplicate, honor preferences and rest days, and never create attendance records',async()=>{
  const now=new Date('2026-11-25T15:05:00Z');
  await runWorkdayReminders(db,now);await runWorkdayReminders(db,now);
  assert.equal((await db.collection('notificaciones').where('destinatarioId','==','worker').get()).size,1);
  assert.equal((await db.collection('asistencias').get()).size,0);
  await db.collection('preferencias_notificaciones').doc('worker').set({jornada:false});
  await runWorkdayReminders(db,new Date('2026-11-26T15:05:00Z'));
  assert.equal((await db.collection('notificaciones').where('destinatarioId','==','worker').get()).size,1);
  const before=(await db.collection('notificaciones').get()).size;
  await runWorkdayReminders(db,new Date('2026-11-29T15:05:00Z'));
  assert.equal((await db.collection('notificaciones').get()).size,before);
});
