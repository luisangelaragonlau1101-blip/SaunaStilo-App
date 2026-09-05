const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const {buildPushPayload}=require('../functions/push-payload');
const {generationConfig,assistantFailure,reserveAssistantRequest,ownedMediaUrls}=require('../functions/assistant-policy');
function read(file){return fs.readFileSync(path.join(__dirname,'..',file),'utf8');}
function loadMaintenance() {
  const code=read('web/sauna-maintenance.js');
  const context={window:{}};
  vm.runInNewContext(code,context);
  return context.window.SaunaMaintenance;
}
function loadMessagingWorker(){
  const code=read('web/firebase-messaging-sw.js');
  const listeners={};const shown=[];const opened=[];const root='https://example.test/SaunaStilo-App/';
  const worker={
    location:{href:root+'firebase-messaging-sw.js'},
    registration:{showNotification:async(t,o)=>shown.push({title:t,options:o})},
    clients:{matchAll:async()=>[],openWindow:async u=>opened.push(u)},
    addEventListener:(n,fn)=>listeners[n]=fn,
  };
  const firebase={initializeApp(){},messaging:()=>({onBackgroundMessage:cb=>worker.background=cb})};
  const context={self:worker,firebase,URL,encodeURIComponent,Promise,console,Date};
  worker.importScripts=()=>{};
  vm.runInNewContext(code,context);
  return {worker,listeners,shown,opened,root};
}
test('asset repair unregisters only this app legacy Flutter worker, preserving messaging and other apps', async()=>{
  const maintenance=loadMaintenance();
  const calls=[];
  const root='https://example.test/SaunaStilo-App/';
  const registrations=[
    {scope:root,active:{scriptURL:root+'flutter_service_worker.js'},unregister:async()=>{calls.push('flutter');return true;}},
    {scope:root,active:{scriptURL:root+'firebase-messaging-sw.js'},unregister:async()=>{calls.push('messaging');return true;}},
    {scope:'https://example.test/other/',active:{scriptURL:'https://example.test/other/flutter_service_worker.js'},unregister:async()=>{calls.push('other');return true;}},
  ];
  await maintenance.repair(root,{navigator:{serviceWorker:{getRegistrations:async()=>registrations}},caches:{keys:async()=>[],delete:async()=>true}});
  assert.deepEqual(calls,['flutter']);
});
test('asset repair preserves unrelated caches and entries from another application',async()=>{
  const maintenance=loadMaintenance();const deleted=[];const root='https://example.test/SaunaStilo-App/';
  const caches={keys:async()=>['flutter-app-cache','sauna-stilo-v1','other-app-cache'],delete:async k=>{deleted.push(k);return true;},open:async()=>({keys:async()=>[]})};
  await maintenance.repair(root,{navigator:{serviceWorker:{getRegistrations:async()=>[]}},caches});
  assert.deepEqual(deleted,['flutter-app-cache','sauna-stilo-v1']);
});
test('a registration transitioning to messaging is not unregistered',async()=>{
  const maintenance=loadMaintenance();let call=0;const root='https://example.test/SaunaStilo-App/';let unregistered=false;
  const registration={scope:root,get active(){call++;return {scriptURL:call===1?root+'flutter_service_worker.js':root+'firebase-messaging-sw.js'};},unregister:async()=>{unregistered=true;return true;}};
  await maintenance.repair(root,{navigator:{serviceWorker:{getRegistrations:async()=>[registration]}},caches:{keys:async()=>[],delete:async()=>true}});
  assert.equal(unregistered,false);
});
test('SDK notification payload is not displayed twice',async()=>{const {worker,shown}=loadMessagingWorker();await worker.background({notification:{title:'Hi',body:'Body'},data:{type:'general'}});assert.equal(shown.length,0);});
test('data-only background message displays exactly one visible notification',async()=>{const {worker,shown}=loadMessagingWorker();await worker.background({data:{title:'Hi',body:'Body',type:'general'}});assert.equal(shown.length,1);});
test('expired data-only call becomes a visible missed invitation, not renewed ringing',async()=>{const {worker,shown}=loadMessagingWorker();await worker.background({data:{title:'Call',body:'Join',type:'llamada',esLlamada:'true',expiresAt:'1'}});assert.equal(shown.length,1);assert.equal(shown[0].options.requireInteraction,false);});
test('notification click remains on installed origin and encodes untrusted IDs',async()=>{const {listeners,opened,root}=loadMessagingWorker();const event={notification:{data:{route:'/mensajes',conversationId:'x y/ñ'},close(){}},waitUntil:p=>p};await listeners.notificationclick(event);assert.equal(opened.length,1);assert.ok(opened[0].startsWith(root));assert.ok(opened[0].includes('x%20y%2F%C3%B1'));});
test('root-level installed app opens its existing root, not a hardcoded Pages or Vercel address',async()=>{const {listeners,opened}=loadMessagingWorker();const event={notification:{data:{},close(){}},waitUntil:p=>p};await listeners.notificationclick(event);assert.equal(opened[0],'https://example.test/SaunaStilo-App/');});
test('click focuses a suitable existing app after navigating and does not open another window',async()=>{const env=loadMessagingWorker();let focused=false;env.worker.clients.matchAll=async()=>[{url:env.root+'old',navigate:async()=>({focus:async()=>{focused=true;}})}];const event={notification:{data:{route:'/mensajes'},close(){}},waitUntil:p=>p};await env.listeners.notificationclick(event);assert.equal(focused,true);assert.equal(env.opened.length,0);});
test('live calls have high priority and no more than sixty seconds TTL on every platform',()=>{const p=buildPushPayload({notificationId:'c',data:{esLlamada:true,fecha:{toMillis:()=>1000}},now:2000});assert.equal(p.android.priority,'high');assert.ok(p.android.ttl<=60000);assert.equal(p.apns.headers['apns-priority'],'10');assert.equal(p.webpush.headers.Urgency,'high');});
test('stale invitations never regain sixty seconds of incoming-call status',()=>{const p=buildPushPayload({notificationId:'c',data:{esLlamada:true,fecha:{toMillis:()=>1000}},now:62000});assert.equal(p.data.esLlamada,'false');assert.equal(p.android.notification.sticky,false);});
test('urgent admin alarm retains its native channel and ordinary notices retain theirs',()=>{const a=buildPushPayload({notificationId:'a',data:{tipo:'alarma_admin'},now:1});const n=buildPushPayload({notificationId:'n',data:{tipo:'general'},now:1});assert.equal(a.android.notification.channelId,'sauna_alarmas_urgentes');assert.equal(n.android.notification.channelId,'sauna_alertas');});
test('Gemini config omits deprecated sampling fields and preserves role instructions',()=>{const c=generationConfig('abc');assert.equal(c.systemInstruction,'abc');assert.equal('temperature'in c,false);assert.equal('topP'in c,false);});
test('provider failures expose useful status but never raw provider secrets/errors',()=>{assert.equal(assistantFailure({status:429}).code,'resource-exhausted');assert.equal(assistantFailure({status:403}).code,'permission-denied');assert.equal(assistantFailure({status:500,message:'secret'}).message.includes('secret'),false);});
test('AI media ownership is restricted to this authenticated user and bucket',()=>{const b='bucket';const url=p=>`https://firebasestorage.googleapis.com/v0/b/${b}/o/${encodeURIComponent(p)}?alt=media`;assert.equal(ownedMediaUrls([url('media/alice/image.png')],'alice',b),true);assert.equal(ownedMediaUrls([url('media/alice/../bob/image.png')],'alice',b),false);assert.equal(ownedMediaUrls(['https://evil.test/media/alice/image.png'],'alice',b),false);});
test('server-side assistant rate limit rejects the ninth call in one minute and resets minute window', async () => {
  let stored;
  class HttpsError extends Error { constructor(code,msg) {super(msg);this.code=code;} }
  const db={collection:()=>({doc:()=>({})}),runTransaction:async fn=>fn({get:async()=>({exists:!!stored,data:()=>stored}),set:(_,data)=>{stored=data;}})};
  for(let i=0;i<8;i++) await reserveAssistantRequest(db,'alice',HttpsError,1000);
  await assert.rejects(()=>reserveAssistantRequest(db,'alice',HttpsError,1000),{code:'resource-exhausted'});
  await reserveAssistantRequest(db,'alice',HttpsError,61000);
  assert.equal(stored.minuteCount,1);
  assert.equal(stored.dayCount,9);
});
test('AI outage uses real Online Smart fallback and never a canned local generator', () => {
  const screen=read('lib/screens/asistente_ia_screen.dart');
  assert.equal(screen.includes(': _responderLocal(limpio)'),false);
  assert.equal(screen.includes('En línea · voz natural'),false);
  const service=read('lib/services/ai_assistant_service.dart');
  assert.match(service,/historial[\s\S]*\.skip/);
  assert.match(service,/ollin-smart-vxs23c\.v2\.appdeploy\.ai\/api\/chat/);
  assert.match(service,/workspace': 'sauna-stilo/);
  assert.match(service,/seconds: 28/);
});
test('manifest identity and reset navigation are relative to the installed app', () => {
  const manifest=JSON.parse(read('web/manifest.json'));
  assert.equal(manifest.id,'./');
  assert.equal(manifest.start_url,'./');
  assert.equal(manifest.scope,'./');
  assert.equal(read('web/reset.html').includes('registration.unregister'),false);
});
