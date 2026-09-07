/* App interaction policy, not DRM or browser screenshot prevention. Paste remains available. */
(() => {
  const insideApp = e => !e.target?.closest?.('iframe');
  for (const name of ['copy','cut','dragstart']) document.addEventListener(name,e=>{if(insideApp(e))e.preventDefault();},true);
  document.addEventListener('contextmenu',e=>{if(insideApp(e)&&!['INPUT','TEXTAREA'].includes(e.target?.tagName))e.preventDefault();},true);
  document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&['c','x','s','p'].includes(e.key.toLowerCase()))e.preventDefault();},true);
  const style=document.createElement('style');style.textContent='flutter-view img,flt-glass-pane img{user-select:none;-webkit-user-drag:none}';document.head.appendChild(style);
})();
