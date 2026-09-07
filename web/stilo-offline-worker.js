/* Public application files only. Never cache authenticated APIs, media or people. */
(() => {
  if (self.__stiloOfflineInstalled) return;
  self.__stiloOfflineInstalled = true;
  const base = new URL('./', self.location.href);
  const CACHE = 'stilo-public-' + base.pathname + '-__STILO_OFFLINE_VERSION__';
  function allowed(input) {
    const u = new URL(input, base);
    if (u.origin !== base.origin) return u.protocol === 'https:' && u.hostname === 'www.gstatic.com' && /^\/firebasejs\/[\w.-]+\/firebase-[\w-]+\.js$/.test(u.pathname);
    if (!u.pathname.startsWith(base.pathname)) return false;
    const p = u.pathname.slice(base.pathname.length);
    return !u.search && (p === '' || p === 'index.html' || p === 'manifest.json' ||
      /^(?:main[.\w-]*|flutter_bootstrap[.\w-]*|flutter|sauna-maintenance|chat-audio-capture|voice-capture|privacy-controls|offline-client)\.js$/.test(p) ||
      /^(?:assets|canvaskit|icons)\/[\w./-]+\.(?:js|wasm|json|bin|png|jpg|svg|ttf|otf|woff2|ogg)$/.test(p) || p === 'favicon.png');
  }
  function canonical(input) { const u = new URL(input,base); u.search=''; u.hash=''; return u.href; }
  async function put(cache,url,response) {if(response && (response.ok || response.type === 'opaque')) await cache.put(url,response.clone());}
  self.addEventListener('install',event=>event.waitUntil((async()=>{
    const response=await fetch(new URL('offline-manifest.json',base),{cache:'no-store',credentials:'omit'});
    if(!response.ok) throw Error('No hay manifiesto público offline.');
    const files=await response.json();
    if(!Array.isArray(files)||files.length>900) throw Error('Manifiesto inválido.');
    const cache=await caches.open(CACHE);
    // Limit parallel downloads and require every listed shell asset before activation.
    for(let i=0;i<files.length;i+=8) await Promise.all(files.slice(i,i+8).map(async file=>{
      const u=canonical(file);if(!allowed(u))throw Error('Ruta no pública.');
      const r=await fetch(u,{cache:'reload',credentials:'omit'});if(!r.ok)throw Error('No se descargó el recurso.');await put(cache,u,r);
    }));
    await self.skipWaiting();
  })()));
  self.addEventListener('activate',event=>event.waitUntil((async()=>{
    // Only our exact application scope; never touch Flutter legacy, push, or another app.
    for(const name of await caches.keys()) if(name.startsWith('stilo-public-'+base.pathname+'-')&&name!==CACHE)await caches.delete(name);
    await self.clients.claim();
  })()));
  self.addEventListener('message',event=>{
    if(event.data?.type!=='stilo-cache-public'||!Array.isArray(event.data.urls)||event.data.urls.length>250)return;
    const source=event.source; if(!source?.url||new URL(source.url).origin!==base.origin)return;
    event.waitUntil((async()=>{const c=await caches.open(CACHE);for(const raw of event.data.urls){
      try{const u=canonical(raw);if(!allowed(u))continue;const r=await fetch(u,{credentials:'omit'});await put(c,u,r);}catch(_){/* Optional public SDKs remain best effort. */}
    }})());
  });
  self.addEventListener('fetch',event=>{
    const request=event.request; if(request.method!=='GET')return;
    const key=canonical(request.url),u=new URL(request.url);
    const navigation=request.mode==='navigate'&&u.origin===base.origin&&(u.pathname===base.pathname||u.pathname===base.pathname+'index.html');
    if(!navigation&&!allowed(key))return;
    // A safe asset path must not turn an arbitrary query endpoint into a cached file.
    if(!navigation&&u.search&&!/^\?v=[A-Za-z0-9._-]+$/.test(u.search))return;
    event.respondWith((async()=>{
      const cache=await caches.open(CACHE);
      if(!navigation){const hit=await cache.match(key);if(hit)return hit;}
      try{const r=await fetch(request);await put(cache,navigation?new URL('index.html',base).href:key,r);return r;}
      catch(error){const hit=await cache.match(navigation?new URL('index.html',base).href:key);if(hit)return hit;throw error;}
    })());
  });
  // Export policy only in isolated worker tests.
  if(typeof module!=='undefined')module.exports={allowed,canonical};
})();
