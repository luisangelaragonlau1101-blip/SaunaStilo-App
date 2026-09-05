const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { repair } = require('../web/sauna-maintenance.js');
const { buildPushPayload } = require('../functions/push-payload.js');
const { generationConfig, assistantFailure, reserveAssistantRequest, ownedMediaUrls } = require('../functions/assistant-policy.js');
const root = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root,p),'utf8');

function workerHarness(base = 'https://example.test/SaunaStilo-App/firebase-messaging-sw.js') {
  const handlers = {}; const notices = []; const opened = []; let background;
  const sandbox = {
    URL, console, Date,
    importScripts() { assert.ok(handlers.notificationclick, 'click handler must precede SDK import'); },
    firebase: {
      initializeApp() {},
      messaging: () => ({ onBackgroundMessage(fn) { background = fn; } }),
    },
    self: {
      location: { href: base },
      addEventListener(name, fn) { handlers[name] = fn; },
      registration: { async showNotification(title, options) { notices.push({title,options}); } },
      clients: { async matchAll() { return []; }, async openWindow(url) { opened.push(url); } },
    },
  };
  vm.runInNewContext(read('web/firebase-messaging-sw.js'), sandbox, { filename: 'firebase-messaging-sw.js' });
  return { handlers, notices, opened, sandbox, background: (p) => background(p) };
}

test('asset repair unregisters only this app legacy Flutter worker, preserving messaging and other apps', async () => {
  const removed = [];
  const scripts = [
    'https://example.test/SaunaStilo-App/flutter_service_worker.js',
    'https://example.test/SaunaStilo-App/firebase-messaging-sw.js',
    'https://example.test/another/flutter_service_worker.js',
  ];
  await repair('https://example.test/SaunaStilo-App/', {
    navigator: { serviceWorker: { getRegistrations: async () => scripts.map(scriptURL => ({active:{scriptURL},unregister:async()=>removed.push(scriptURL)})) } },
  });
  assert.deepEqual(removed,[scripts[0]]);
});

test('asset repair preserves unrelated caches and entries from another application', async () => {
  const removed = []; const opened = [];
  await repair('https://example.test/SaunaStilo-App/', { caches: {
    keys: async () => ['flutter-app-cache','private-drafts','firebase-messaging'],
    open: async name => { opened.push(name); return {
      keys: async () => [{url:'https://example.test/SaunaStilo-App/main.dart.js'}, {url:'https://example.test/another/main.dart.js'}],
      delete: async request => removed.push(request.url),
    }; },
  } });
  assert.deepEqual(opened,['flutter-app-cache']);
  assert.deepEqual(removed,['https://example.test/SaunaStilo-App/main.dart.js']);
});

test('a registration transitioning to messaging is not unregistered', async () => {
  let removed = false;
  await repair('https://example.test/', {navigator:{serviceWorker:{getRegistrations:async()=>[{
    active:{scriptURL:'https://example.test/flutter_service_worker.js'},
    waiting:{scriptURL:'https://example.test/firebase-messaging-sw.js'},unregister:async()=>{removed=true;}
  }]}}});
  assert.equal(removed,false);
});

test('SDK notification payload is not displayed twice', async () => {
  const w = workerHarness();
  await w.background({ notification: {title:'Already displayed'}, data:{}, messageId:'1' });
  assert.equal(w.notices.length,0);
});

test('data-only background message displays exactly one visible notification', async () => {
  const w = workerHarness();
  await w.background({data:{notificationId:'n1',title:'Llamada',body:'Abre el chat',esLlamada:'true',expiresAt:String(Date.now()+60000)}});
  assert.equal(w.notices.length,1);
  assert.equal(w.notices[0].options.requireInteraction,true);
  assert.equal(w.notices[0].options.icon,'https://example.test/SaunaStilo-App/icons/Icon-192.png');
});

test('expired data-only call becomes a visible missed invitation, not renewed ringing', async () => {
  const w = workerHarness();
  await w.background({data:{esLlamada:'true',expiresAt:'1',title:'Llamada'}});
  assert.equal(w.notices.length,1);
  assert.match(w.notices[0].title,/Llamada recibida/);
  assert.equal(w.notices[0].options.requireInteraction,false);
});

test('notification click remains on installed origin and encodes untrusted IDs', async () => {
  const w = workerHarness(); let work; let stopped = false;
  w.handlers.notificationclick({stopImmediatePropagation(){stopped=true;},notification:{close(){},data:{FCM_MSG:{data:{notificationId:'abc&redirect=evil',link:'https://evil.test/'}}}},waitUntil(p){work=p;}});
  await work;
  assert.equal(stopped,true);
  assert.deepEqual(w.opened,['https://example.test/SaunaStilo-App/?notification=abc%26redirect%3Devil']);
});

test('root-level installed app opens its existing root, not a hardcoded Pages or Vercel address', async () => {
  const w = workerHarness('https://example.test/firebase-messaging-sw.js'); let work;
  w.handlers.notificationclick({stopImmediatePropagation(){},notification:{close(){},data:{notificationId:'one'}},waitUntil(p){work=p;}});
  await work;
  assert.deepEqual(w.opened,['https://example.test/?notification=one']);
});

test('click focuses a suitable existing app after navigating and does not open another window', async () => {
  const w = workerHarness(); let work; let focused=false; let navigated;
  w.sandbox.self.clients.matchAll = async () => [{url:'https://example.test/SaunaStilo-App/',navigate:async url=>{navigated=url;return {focus:async()=>{focused=true;}};}}];
  w.handlers.notificationclick({stopImmediatePropagation(){},notification:{close(){},data:{notificationId:'one'}},waitUntil(p){work=p;}});
  await work;
  assert.equal(focused,true);
  assert.equal(navigated,'https://example.test/SaunaStilo-App/?notification=one');
  assert.equal(w.opened.length,0);
});

test('live calls have high priority and no more than sixty seconds TTL on every platform', () => {
  const p = buildPushPayload({notificationId:'one',now:120000,data:{titulo:'Angel',esLlamada:true,fecha:{toMillis:()=>110000}}});
  assert.equal(p.webpush.headers.TTL,'50');
  assert.equal(p.android.ttl,50000);
  assert.equal(p.apns.headers['apns-expiration'],'170');
  assert.equal(p.apns.headers['apns-push-type'],'alert');
  assert.equal(p.webpush.notification.requireInteraction,true);
});

test('stale invitations never regain sixty seconds of incoming-call status', () => {
  const p = buildPushPayload({notificationId:'one',now:200000,data:{esLlamada:true,fecha:{toMillis:()=>1}}});
  assert.equal(p.data.esLlamada,'false');
  assert.equal(p.webpush.notification.requireInteraction,false);
  assert.match(p.notification.body,/Recibiste/);
});

test('urgent admin alarm retains its native channel and ordinary notices retain theirs', () => {
  assert.equal(buildPushPayload({notificationId:'x',data:{tipo:'alarma_admin'}}).android.notification.channelId,'sauna_alarmas_urgentes');
  assert.equal(buildPushPayload({notificationId:'x',data:{tipo:'general'}}).android.notification.channelId,'sauna_alertas');
});

test('Gemini config omits deprecated sampling fields and preserves role instructions', () => {
  assert.deepEqual(generationConfig('private role boundary'),{maxOutputTokens:2048,systemInstruction:'private role boundary'});
});

test('provider failures expose useful status but never raw provider secrets/errors', () => {
  assert.equal(assistantFailure({status:403,message:'secret credential'}).code,'failed-precondition');
  assert.equal(assistantFailure({status:429}).code,'resource-exhausted');
  assert.equal(assistantFailure({status:500,message:'secret credential'}).message.includes('secret'),false);
});

test('AI media ownership is restricted to this authenticated user and bucket', () => {
  const b='saunastiloapp-17e15.firebasestorage.app';
  const url=(object)=>`https://firebasestorage.googleapis.com/v0/b/${b}/o/${encodeURIComponent(object)}?alt=media`;
  assert.equal(ownedMediaUrls([url('media/alice/images/image.png')],'alice',b),true);
  assert.equal(ownedMediaUrls([url('media/bob/images/image.png')],'alice',b),false);
  assert.equal(ownedMediaUrls([url('media/alice/../bob/image.png')],'alice',b),false);
  assert.equal(ownedMediaUrls(['https://evil.test/media/alice/image.png'],'alice',b),false);
});

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
  assert.match(service,/ollin-smart-vxs23c\.v2\.appdeploy\.ai\/api\/chat/);
  assert.match(service,/workspace': 'sauna-stilo/);
  assert.match(service,/_onlineSmartResponse/);
  assert.match(service,/seconds: 28/);
});

test('manifest identity and reset navigation are relative to the installed app', () => {
  const manifest=JSON.parse(read('web/manifest.json'));
  assert.equal(manifest.id,'./');
  assert.equal(manifest.start_url,'./');
  assert.equal(manifest.scope,'./');
  assert.equal(read('web/reset.html').includes('registration.unregister'),false);
});
