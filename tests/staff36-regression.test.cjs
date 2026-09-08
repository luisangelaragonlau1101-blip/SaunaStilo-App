const test=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs');
const read=p=>fs.readFileSync(p,'utf8');
test('background permission checks never ask Android again and a denied permission is prompted only once',()=>{
 const receiver=read('lib/widgets/avisos_sonoros.dart'),push=read('lib/services/push_notifications_service.dart');
 assert.match(receiver,/requestPermission: false/);assert.match(receiver,/sauna\.push\.promptShown/);assert.match(receiver,/preferences\.getBool\(key\) == true/);
 assert.match(push,/requestPermission \? await _messaging.requestPermission/);
 assert.doesNotMatch(receiver,/if \(mounted\) _showPushAction\('No se pudieron sincronizar/);
});
test('meal controls reuse the verified attendance actions and administrators never register their own attendance',()=>{
 const source=read('lib/widgets/jornada_compacta.dart');assert.match(source,/_register\('solicitar_comida'\)/);assert.match(source,/_register\('regreso_comida'\)/);assert.match(source,/widget.usuario.rol == AppRoles.admin \? const SizedBox.shrink/);assert.match(source,/result.data\['exito'\] != true/);
});
test('personal tasks and shopping creation and edits are administrative while extra reports are separate',()=>{
 const panel=read('lib/screens/personal_day_screen.dart'),service=read('tools/online-smart34/personal-day.mjs');
 assert.match(panel,/canEdit=_admin;/);assert.match(panel,/if\(_admin\)IconButton\(tooltip:'Agregar/);assert.match(panel,/ExtraWorkScreen/);
 assert.match(service,/u.role==='admin','Las tareas, comidas, compras y eventos/);assert.doesNotMatch(service,/u.role==='admin'\|\|item.createdBy===u.uid/);
});
test('home exposes one canonical project-task workflow, inbox and no secret-derived privileges',()=>{
 const home=read('lib/screens/operations_shell.dart');assert.match(home,/a.id != 'proyectos'/);assert.match(home,/AdminInboxScreen/);assert.match(home,/EngineeringScreen/);
 const permissions=read('lib/screens/engineering_screen.dart');assert.match(permissions,/widget.administrator.rol != AppRoles.admin/);assert.doesNotMatch(permissions,/Osiris|Naomi|Zaldívar/);
});
