const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
test('native secure flag is never cleared by a profile override',()=>{
 const native=read('android/app/src/main/kotlin/com/saunastylo/saunastylo/MainActivity.kt');assert.match(native,/onResume/);assert.doesNotMatch(native,/clearFlags/);assert.match(native,/FLAG_SECURE/);
 assert.doesNotMatch(read('lib/widgets/screen_security_guard.dart'),/\.update\(/);
});
test('explicit outbound share calls and selectable company messages are removed',()=>{
 function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(d=>d.isDirectory()?files(dir+'/'+d.name):[dir+'/'+d.name]);}
 for(const p of files('lib').filter(p=>p.endsWith('.dart')))assert.doesNotMatch(read(p),/Share\.shareXFiles\(|SharePlus\.instance\.share\(|Clipboard\.setData\(/,p);
 for(const p of ['lib/screens/mensajes_equipo_screen.dart','lib/widgets/team_notes_strip.dart','lib/widgets/official_voice_reply.dart'])assert.doesNotMatch(read(p),/SelectableText/);
 const viewer=read('lib/widgets/protected_media_viewer.dart');assert.match(viewer,/allowPrinting:false/);assert.match(viewer,/allowSharing:false/);assert.doesNotMatch(viewer,/launchUrl/);
});
test('privacy clipboard controls preserve paste and inputs',()=>{
 const handlers={},document={addEventListener:(k,f)=>handlers[k]=f,createElement:()=>({}),head:{appendChild(){}}};
 vm.runInNewContext(read('web/privacy-controls.js'),{document});
 for(const name of ['copy','cut','dragstart']){let blocked=false;handlers[name]({target:{closest:()=>null},preventDefault:()=>blocked=true});assert.equal(blocked,true);}
 assert.equal(handlers.paste,undefined);let inputBlocked=false;handlers.contextmenu({target:{tagName:'INPUT',closest:()=>null},preventDefault:()=>inputBlocked=true});assert.equal(inputBlocked,false);
 const menu=read('lib/services/external_transfer.dart');assert.match(menu,/ContextMenuButtonType.copy/);assert.doesNotMatch(menu,/ContextMenuButtonType.paste/);
});
test('learning stays user-scoped local and the home keeps the general alert',()=>{
 for(const p of ['lib/academy/learning_progress.dart','lib/games/round_match.dart'])assert.doesNotMatch(read(p),/FirebaseFirestore|FirebaseAuth|httpsCallable/);
 const home=read('lib/screens/operations_shell.dart');assert.match(home,/HomeProgressPanel/);assert.ok(home.indexOf("if (alerts.isNotEmpty)")<home.indexOf('HomeProgressPanel(user:'));assert.match(home,/StiloAcademyScreen\(userId: widget.usuario.id\)/);
});
