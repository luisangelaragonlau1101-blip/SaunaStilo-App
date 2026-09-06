/* Signed-out browser only. Do not register attendance, messages or company users. */
const {chromium}=require('playwright'),fs=require('node:fs');
(async()=>{fs.mkdirSync('smoke-results',{recursive:true});const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});const context=await browser.newContext({viewport:{width:390,height:844}}),page=await context.newPage();
const report={cacheReady:false,offlineFrame:false,offlineLogin:false,validationWorked:false,privateResourcesCached:[],errors:[],failedRequests:[]};
page.on('pageerror',e=>report.errors.push(e.message));page.on('requestfailed',r=>report.failedRequests.push({url:r.url(),failure:r.failure()?.errorText}));
async function semantics(){const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(x=>x.click());}
async function cached(){return page.evaluate(async()=>{const out=[];for(const key of await caches.keys()){if(!key.startsWith('stilo-public-'))continue;for(const req of await(await caches.open(key)).keys())out.push(req.url);}return out;});}
try{
await page.addInitScript(()=>{window.addEventListener('flutter-first-frame',()=>window.__offlineFrame=true)});
await page.goto('http://127.0.0.1:8177/',{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.__offlineFrame===true,{},{timeout:60000});await semantics();
await page.getByRole('button',{name:'Entrar a mi espacio',exact:true}).waitFor({state:'visible',timeout:60000});
await page.waitForFunction(()=>navigator.serviceWorker.controller!=null,{},{timeout:90000});
const deadline=Date.now()+60000;while(Date.now()<deadline){report.cached=await cached();if(['firebase-app','firebase-auth','firebase-firestore'].every(part=>report.cached.some(u=>u.includes(part)))){report.cacheReady=true;break;}await new Promise(r=>setTimeout(r,300));}
if(!report.cacheReady)throw Error('Required public Firebase libraries were not cached.');
report.privateResourcesCached=report.cached.filter(u=>/firestore.googleapis|identitytoolkit|firebasestorage|cloudfunctions|\/api\//.test(u));if(report.privateResourcesCached.length)throw Error('Private resources entered public cache.');
await context.setOffline(true);await page.reload({waitUntil:'domcontentloaded',timeout:45000});await page.waitForFunction(()=>window.__offlineFrame===true,{},{timeout:45000});report.offlineFrame=true;await semantics();
const enter=page.getByRole('button',{name:'Entrar a mi espacio',exact:true});await enter.waitFor({state:'visible',timeout:45000});report.offlineLogin=true;
await enter.click();await page.waitForFunction(()=>document.body.innerText.includes('Ingresa tu correo electrónico')&&document.body.innerText.includes('Ingresa tu contraseña'),{},{timeout:10000});report.validationWorked=true;
}finally{report.cached=await cached().catch(()=>report.cached||[]);report.visibleText=await page.locator('body').innerText().catch(()=>'');await page.screenshot({path:'smoke-results/offline-login.png',fullPage:true}).catch(()=>{});fs.writeFileSync('smoke-results/offline-check.json',JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
