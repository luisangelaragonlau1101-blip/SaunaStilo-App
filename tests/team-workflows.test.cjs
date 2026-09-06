const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {reminderSlot} = require('../functions/reminder-policy');
const {buildPushPayload} = require('../functions/push-payload');
const read = p => fs.readFileSync(p,'utf8');
const at = (s) => new Date('2026-09-07T'+s+'-06:00');
const user = {rol:'trabajador',horaEntrada:'09:00',horaSalida:'19:00'};
test('reminders have four idempotent slots and stop after entry or exit', () => {
  for (const [time,slot] of [['09:00:00',0],['09:15:00',1],['09:30:00',2],['09:45:00',3]]) assert.equal(reminderSlot({type:'entrada',user,now:at(time)}).slot,slot);
  assert.equal(reminderSlot({type:'entrada',user,now:at('10:00:00')}),null);
  assert.equal(reminderSlot({type:'entrada',user,now:at('09:15:00'),attendance:{horaEntrada:true}}),null);
  assert.equal(reminderSlot({type:'salida',user,now:at('19:15:00'),attendance:{horaEntrada:true,horaSalida:true}}),null);
});
test('respect each work schedule, non-working Saturday and lunch state', () => {
  assert.equal(reminderSlot({type:'entrada',user:{...user,horaEntrada:'10:00'},now:at('09:30:00')}),null);
  assert.equal(reminderSlot({type:'salida',user,now:at('19:15:00'),attendance:{horaEntrada:true}}).slot,1);
  assert.equal(reminderSlot({type:'comida',user,now:at('15:15:00')}),null);
  assert.equal(reminderSlot({type:'comida',user,now:at('15:15:00'),attendance:{horaEntrada:true,salidaComidaSolicitada:true}}),null);
  assert.equal(reminderSlot({type:'entrada',user,now:new Date('2026-09-05T09:15:00-06:00')}),null);
  assert.ok(reminderSlot({type:'entrada',user:{...user,trabajaSabados:true},now:new Date('2026-09-05T09:15:00-06:00')}));
});
test('personal notices retain priority and direct conversation identifier', () => {
  const payload=buildPushPayload({notificationId:'private',data:{tipo:'aviso_personal',conversacionId:'privado_ab'}});
  assert.equal(payload.android.priority,'high');assert.equal(payload.webpush.notification.silent,false);
  assert.equal(payload.webpush.notification.requireInteraction,true);assert.equal(payload.data.conversationId,'privado_ab');
});
test('dashboard retains the all-team alert ahead of secondary actions', () => {
  const dashboard=read('lib/screens/futuristic_dashboard_screen.dart');
  assert.match(dashboard,/\['alerta_general', 'asistencia', 'tareas', 'mensajes'/);
  const shell=read('lib/screens/operations_shell.dart');
  for(const name of ['Inicio','Comunidad','Chats','Tareas','Perfil'])assert.ok(shell.includes(`label: '${name}'`));
  assert.match(shell,/IndexedStack/);
});
test('private chats preserve members and do not lose a saved message when push fails', () => {
  const s=read('lib/services/team_contact_service.dart');
  assert.match(s,/Preserve legacy member order/);
  assert.match(s,/batch.update\(ref, \{'actualizadaEn'/);
  assert.match(s,/await batch.commit/);assert.match(s,/return false/);
  assert.match(s,/Abre tu conversación para leer el mensaje privado/);
});

test('attendance confirms server success and cannot silently accept invalid coordinates', () => {
  const s=read('lib/services/asistencia_service.dart');
  assert.match(s,/if \(!ubicacionValida\) throw StateError/);
  assert.match(s,/data\['exito'\] != true/);
  assert.match(read('lib/screens/jornada_screen.dart'),/Registrar entrada/);
});
test('master task creation never changes project status without admin role', () => {
  const s=read('lib/services/actividades_service.dart');
  assert.doesNotMatch(s,/batch.update\(proyectoRef/);
  assert.match(s,/await _db.runTransaction/);
  assert.match(s,/doc\('tarea_\$\{ref.id\}'\)/);
  assert.match(s,/members.contains\(target.id\)/);
  assert.match(read('firestore.rules'),/allow create: if isAdmin\(\) \|\| validMasterTask\(\)/);
});
test('Online Smart iframe sends no authentication tokens or private profile to provider', () => {
  const page=read('lib/screens/online_smart_screen.dart');
  assert.match(page,/'workspace'\s*:\s*'sauna-stilo'/);
  assert.doesNotMatch(page,/getIdToken|correo|sueldo|clientes/);
  assert.match(read('lib/screens/online_smart_embed_web.dart'),/no-referrer/);
});

test('project messages and member notices commit together',()=>{
 const service=read('lib/services/proyecto_chat_service.dart');
 assert.equal((service.match(/await batch.commit\(\);/g)||[]).length,3);
 assert.match(service,/miembros.where/);
 assert.doesNotMatch(service,/rolesDestinatarios: const \['admin'\]/);
});

test('reminders expire after fifteen minutes and queries filter recipients on the server',()=>{
 const p=buildPushPayload({notificationId:'entry',data:{tipo:'asistencia_entrada'}});
 assert.equal(p.webpush.headers.TTL,'900');
 const s=read('lib/services/notificaciones_service.dart');
 assert.match(s,/Filter.or/);assert.doesNotMatch(s,/_ref.snapshots/);
 assert.match(read('firestore.rules'),/allow read: if notificationVisible/);
});
