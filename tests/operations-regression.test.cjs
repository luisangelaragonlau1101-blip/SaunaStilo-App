const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
test('warehouse changes stock only after reading request and commits audit atomically',()=>{
 const s=read('lib/services/warehouse_operations_service.dart');assert.match(s,/await tx.get\(req\)/);assert.match(s,/available<qty/);assert.match(s,/devueltoConfirmadoAdmin.*==true\)return/);assert.match(s,/collection\('historial'\).doc\(action\)/);
 assert.doesNotMatch(read('lib/screens/admin_solicitudes_herramientas_screen.dart'),/FieldValue.increment/);
});
test('screenshot policy covers navigator and Android window, editable only by admin',()=>{
 assert.match(read('lib/main.dart'),/builder:.*ScreenSecurityGuard/);assert.match(read('lib/widgets/team_profile_details.dart'),/if\(_admin\)|if \(_admin\)/);
 const kotlin=read('android/app/src/main/kotlin/com/saunastylo/saunastylo/MainActivity.kt');assert.match(kotlin,/FLAG_SECURE/);assert.match(kotlin,/sauna_stilo\/security/);
 const safe=read('firestore.rules').split('function isSafeOwnProfileUpdate')[1].split('function isSafeNotificationCreate')[0];assert.doesNotMatch(safe,/bloquearCapturas/);
});
test('offline worker caches public shell only, never Firebase private storage or API',()=>{
 const handlers={},module={exports:{}};vm.runInNewContext(read('web/stilo-offline-worker.js'),{self:{location:{href:'https://sauna.example/SaunaStilo-App/stilo-offline-worker.js'},addEventListener:(k,f)=>handlers[k]=f},URL,module});
 const {allowed}=module.exports;for(const url of ['assets/assets/logo_saunastilo.png','main.12345678.dart.js','index.html','canvaskit/canvaskit.wasm','https://www.gstatic.com/firebasejs/12.1.0/firebase-app.js'])assert.equal(allowed(url),true,url);
 for(const url of ['/another-app/main.dart.js','https://firestore.googleapis.com/v1/data','https://firebasestorage.googleapis.com/v0/private','api/users.json','assets/private?token=abc'])assert.equal(allowed(url),false,url);
 assert.equal(typeof handlers.fetch,'function');
});
test('offline writing requires trusted device and drafts stay distinct from assignments',()=>{
 assert.match(read('lib/services/offline_workspace.dart'),/confirmDevice/);assert.match(read('lib/services/offline_workspace.dart'),/currentUser\?\.uid != uid/);assert.match(read('lib/screens/modal_asignar_actividades.dart'),/Aún NO es una tarea asignada/);assert.doesNotMatch(read('lib/screens/project_workspace_screen.dart'),/httpsCallable\('assignProjectActivity'/);
});
