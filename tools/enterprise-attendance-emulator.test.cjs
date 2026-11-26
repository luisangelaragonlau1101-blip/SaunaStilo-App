const test = require('node:test'), assert = require('node:assert/strict');
const {createRequire} = require('node:module');
const r = createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp} = r('firebase-admin/app');
const {getFirestore} = r('firebase-admin/firestore');
const {runEnterpriseAttendance} = require('../functions/enterprise-attendance');
const {ZONES} = require('../functions/attendance-ledger');
let app, db;
const now = new Date('2026-11-25T15:00:00Z');
const call = (uid,data,time=now) => runEnterpriseAttendance({db,uid,data,now:time});
test.before(async()=>{
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST,'Isolated emulator required');
  app=initializeApp({projectId:'demo-sauna-attendance-2026'});db=getFirestore(app);
  for(const [id,rol,manual,activo] of [['worker','trabajador',false,true],['admin','admin',true,true],['accountant','contabilidad',true,true],['inactive','trabajador',true,false]])
    await db.collection('usuarios').doc(id).set({rol,activo,asistenciaManualPermitida:manual});
});
test.after(async()=>deleteApp(app));
test('GPS cannot be bypassed with a manual flag and employees cannot record another identity',async()=>{
  await assert.rejects(call('worker',{action:'record',movement:'entrada',manual:true}));
  await assert.rejects(call('worker',{action:'record',movement:'entrada',latitud:0,longitud:0}));
  await assert.rejects(call('worker',{action:'record',movement:'entrada',userId:'admin',manual:true}));
  await assert.rejects(call('inactive',{action:'record',movement:'entrada',manual:true}));
  assert.equal((await db.collection('asistencias').get()).size,0);
  const result=await call('worker',{action:'record',movement:'entrada',latitud:ZONES[0].lat,longitud:ZONES[0].lon,horaEntrada:'2000-01-01'});
  assert.equal(result.data.horaEntrada,now.toISOString());
  assert.equal(result.data.registroManual,false);
});
test('authorized office roles can record their own day and repeated requests keep the original server time',async()=>{
  for(const uid of ['admin','accountant']){
    const request={action:'record',movement:'entrada',manual:true,requestId:'own_entry'};
    const first=await call(uid,request), retry=await call(uid,request,new Date('2026-11-25T16:00:00Z'));
    assert.equal(first.data.horaEntrada,now.toISOString());assert.equal(retry.data.horaEntrada,first.data.horaEntrada);
    assert.equal(retry.yaRegistrada,true);assert.equal(first.data.latitudRegistro,undefined);
    assert.equal((await db.collection('empresa_auditoria').where('usuarioId','==',uid).get()).size,1);
  }
});
test('temporary outings require an explicit return before finishing and preserve separate timestamps',async()=>{
  const result=await call('admin',{action:'pause',direction:'out',kind:'baño',manual:true,requestId:'bathroom'},new Date('2026-11-25T16:00:00Z'));
  assert.equal(result.data.pausasJornada.length,1);
  await assert.rejects(call('admin',{action:'record',movement:'salida',manual:true},new Date('2026-11-25T16:05:00Z')));
  await call('admin',{action:'pause',direction:'in',pauseId:'bathroom',manual:true,requestId:'bathroom_back'},new Date('2026-11-25T16:05:00Z'));
  const end=await call('admin',{action:'record',movement:'salida',manual:true},new Date('2026-11-25T20:00:00Z'));
  assert.equal(end.data.pausasJornada[0].regreso,'2026-11-25T16:05:00.000Z');
  assert.equal(end.data.horaSalida,'2026-11-25T20:00:00.000Z');
});
