/* Public shell only; private persistence needs the trusted-device consent. */
(() => {
  async function prepare() {
    if(!('serviceWorker' in navigator)||!window.isSecureContext)return;
    try {
      const base=new URL('./',document.baseURI),all=await navigator.serviceWorker.getRegistrations();
      let r=all.find(x=>x.scope===base.href&&/firebase-messaging-sw\.js/.test(x.active?.scriptURL||''));
      if(r)await r.update();else r=await navigator.serviceWorker.register(new URL('stilo-offline-worker.js',base),{scope:base.pathname});
      const sent=new Set();
      const warm=()=>{
        const worker=r.active;if(!worker||worker.state!=='activated')return;
        const urls=performance.getEntriesByType('resource').map(x=>x.name).filter(raw=>{try{const u=new URL(raw);return u.protocol==='https:'&&u.hostname==='www.gstatic.com'&&/^\/firebasejs\/[\w.-]+\/firebase-[\w-]+\.js$/.test(u.pathname)&&!sent.has(u.href);}catch(_){return false;}}).slice(-250);
        if(urls.length){worker.postMessage({type:'stilo-cache-public',urls});for(const u of urls)sent.add(u);}
      };
      const target=r.installing||r.waiting||r.active;
      if(target?.state==='activated')warm();else target?.addEventListener('statechange',()=>{if(target.state==='activated')warm();});
      // Firebase libraries may load after the first Flutter frame; never warm private request URLs.
      if(window.PerformanceObserver){const observer=new PerformanceObserver(warm);observer.observe({type:'resource',buffered:true});setTimeout(()=>observer.disconnect(),120000);}
      for(const delay of [1000,3000,8000,15000,30000,60000])setTimeout(warm,delay);
    } catch (_) {console.info('[Sauna Stilo] Copia no preparada; vuelve a abrir con conexión.');}
  }
  window.addEventListener('flutter-first-frame',prepare,{once:true});
})();
