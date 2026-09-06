/* Only a signed-out browser: no company credentials, messages or real attendance. */
const {chromium}=require('playwright');const fs=require('node:fs');
(async()=>{fs.mkdirSync('smoke-results',{recursive:true});const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});const context=await browser.newContext({viewport:{width:390,height:844}});const page=await context.newPage();const report={cacheReady:false,offlineFrame:false,offlineLogin:false,privateResourcesCached:[]};try{
await page.addInitScript(()=>{window.addEventListener('flutter-first-frame',()=>window.__offlineFrame=true)});
await page.goto('http://127.0.0.1:8177/',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>window.__offlineFrame===true,{},{timeout:60000});
await page.waitForFunction(()=>navigator.serviceWorker.controller!=null,{},{timeout:90000});
await page.waitForFunction(async()=>{const keys=await caches.keys();for(const key of keys.filter(x=>x.startsWith('stilo-public-'))){const c=await caches.open(key);const files=await c.keys();if(files.some(x=>/firebase-app/.test(x.url))&&files.some(x=>/firebase-auth/.test(x.url))&&files.some(x=>/firebase-firestore/.test(x.url)))return true;}return false;},{},{timeout:60000});
report.cacheReady=true;report.cached=await page.evaluate(async()=>{const out=[];for(const key of await caches.keys()){if(!key.startsWith('stilo-public-'))continue;for(const req of await (await caches.open(key)).keys())out.push(req.url);}return out;});
report.privateResourcesCached=report.cached.filter(u=>/firestore.googleapis|identitytoolkit|firebasestorage|cloudfunctions|\/api\//.test(u));if(report.privateResourcesCached.length)throw Error('Private resource entered public cache.');
await context.setOffline(true);await page.reload({waitUntil:'domcontentloaded',timeout:45000});await page.waitForFunction(()=>window.__offlineFrame===true,{},{timeout:45000});report.offlineFrame=true;
const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(x=>x.click());
await page.getByText('Correo electrónico',{exact:false}).first().waitFor({state:'visible',timeout:45000});report.offlineLogin=true;
await page.screenshot({path:'smoke-results/offline-login.png',fullPage:true});
}finally{fs.writeFileSync('smoke-results/offline-check.json',JSON.stringify(report,null,2));await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1});
