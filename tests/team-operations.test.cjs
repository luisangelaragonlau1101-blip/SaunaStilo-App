const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {canAssignProjectTask,validateTaskInput,remindersDue} = require('../functions/team-operations-policy');
const allowed = {uid:'master',targetId:'worker',caller:{rol:'maestro'},target:{rol:'trabajador'},project:{encargados:['master','worker']}};

test('master can assign only to an active member of a project they belong to',()=>{
  assert.equal(canAssignProjectTask(allowed),true);
  assert.equal(canAssignProjectTask({...allowed,project:{encargados:['worker']}}),false);
  assert.equal(canAssignProjectTask({...allowed,targetId:'outsider'}),false);
  assert.equal(canAssignProjectTask({...allowed,caller:{rol:'trabajador'}}),false);
  assert.equal(canAssignProjectTask({...allowed,caller:{rol:'almacenista'}}),false);
  assert.equal(canAssignProjectTask({...allowed,target:{rol:'admin'}}),false);
  assert.equal(canAssignProjectTask({...allowed,caller:{rol:'maestro',activo:false}}),false);
  assert.equal(canAssignProjectTask({...allowed,target:{rol:'trabajador',activo:false}}),false);
  assert.equal(canAssignProjectTask({...allowed,uid:''}),false);
});
test('task input is bounded and cannot trust a caller-supplied administrator role',()=>{
  const now=Date.parse('2026-09-07T15:00:00Z');
  const input={requestId:'request_123',proyectoId:'project_123',trabajadorId:'worker',titulo:'Lijar la banca',descripcion:'Subir evidencia',fechaTermino:'2026-09-08T15:00:00Z',rol:'admin'};
  assert.equal('rol' in validateTaskInput(input,now),false);
  for(const change of [{titulo:''},{titulo:'x'.repeat(151)},{proyectoId:'a/b'},{fechaTermino:'2026-09-06T15:00:00Z'},{fechaTermino:'2028-01-01T00:00:00Z'},{descripcion:'x'.repeat(2001)}]) assert.throws(()=>validateTaskInput({...input,...change},now));
});
test('repeated entry reminders are bounded and stop when entry exists',()=>{
  const user={rol:'trabajador',horaEntrada:'09:00'};
  const at=time=>new Date(`2026-09-07T${time}:00Z`);
  assert.deepEqual(remindersDue(user,{},at('15:00')),[]);
  assert.deepEqual(remindersDue(user,{},at('15:15')).map(r=>r.slot),[1]);
  assert.deepEqual(remindersDue(user,{},at('15:30')).map(r=>r.slot),[2]);
  assert.deepEqual(remindersDue(user,{},at('15:45')).map(r=>r.slot),[3]);
  assert.deepEqual(remindersDue(user,{},at('16:00')),[]);
  assert.deepEqual(remindersDue(user,{horaEntrada:true},at('15:15')),[]);
});
test('meal and exit reminders stop after their records and do not run on a finished shift',()=>{
  const user={rol:'trabajador'};
  assert.equal(remindersDue(user,{horaEntrada:true},new Date('2026-09-07T21:15:00Z'))[0].action,'comida');
  assert.deepEqual(remindersDue(user,{horaEntrada:true,salidaComidaSolicitada:true},new Date('2026-09-07T21:15:00Z')),[]);
  assert.equal(remindersDue(user,{horaEntrada:true},new Date('2026-09-08T01:15:00Z'))[0].action,'salida');
  assert.deepEqual(remindersDue(user,{horaEntrada:true,horaSalida:true},new Date('2026-09-08T01:15:00Z')),[]);
});
test('weekends, inactive users and administrator schedules do not get unsolicited recurring reminders',()=>{
  for(const user of [{rol:'trabajador'},{rol:'trabajador',activo:false},{rol:'admin'}]) assert.deepEqual(remindersDue(user,{},new Date('2026-09-05T15:15:00Z')),[]);
  assert.equal(remindersDue({rol:'trabajador',trabajaSabados:true},{},new Date('2026-09-05T15:15:00Z')).length,1);
  assert.deepEqual(remindersDue({rol:'trabajador',trabajaSabados:true},{},new Date('2026-09-06T15:15:00Z')),[]);
});
test('private message text stays in the protected conversation and is not copied into general notifications',()=>{
  const service=fs.readFileSync('lib/services/team_contact_service.dart','utf8');
  assert.match(service,/collection\('mensajes'\)/);
  assert.match(service,/Abre tu conversación para leer el mensaje privado/);
  assert.match(service,/await batch.commit\(\)/);
  assert.match(service,/Preserve legacy member order/);
  const overlay=fs.readFileSync('lib/widgets/personal_message_overlay.dart','utf8');
  assert.match(overlay,/where\('destinatarioId', isEqualTo: widget.usuario.id\)/);
  assert.match(overlay,/content\['autorId'\] != data\['creadoPor'\]/);
});
test('embedded assistant does not receive Firebase sessions or company records',()=>{
  const host=fs.readFileSync('lib/screens/online_smart_screen.dart','utf8');
  assert.match(host,/workspace': 'sauna-stilo/);
  assert.doesNotMatch(host,/getIdToken|fcmTokens|collection\('clientes'\)/);
  assert.match(fs.readFileSync('lib/screens/online_smart_embed_web.dart','utf8'),/allow-scripts allow-same-origin allow-forms allow-popups/);
});
test('first attendance entry is read through an owner query instead of a missing protected document',()=>{
  const card=fs.readFileSync('lib/widgets/jornada_compacta.dart','utf8');
  assert.match(card,/where\('trabajadorId', isEqualTo: widget.usuario.id\)/);
  assert.match(card,/httpsCallable\('updateAttendance'/);
  assert.doesNotMatch(card,/\.collection\('asistencias'\)\.doc/);
});
