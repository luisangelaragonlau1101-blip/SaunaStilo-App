// Signed-out airplane-mode QA. No production account, alert, task or inventory writes.
const {chromium}=require('playwright');
const fs=require('node:fs');
(async()=>{
 fs.mkdirSync('smoke-results',{recursive:true});
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:390,height:844}}),page=await context.newPage();
 const report={offline:false,started:[],resumed:false,errors:[]};
 page.on('pageerror',e=>report.errors.push(e.message));
 await page.addInitScript(()=>window.addEventListener('flutter-first-frame',()=>window.__partyFrame=true));
 async function frame(){await page.waitForFunction(()=>window.__partyFrame===true,{},{timeout:60000});const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(x=>x.click());}
 async function lobby(){const entry=page.getByRole('button',{name:'Juegos sin conexión · hasta 4',exact:true});await entry.waitFor({timeout:30000});await entry.click();await page.getByText('ELIGE TU PAUSA',{exact:true}).waitFor();}
 async function stored(){return page.evaluate(()=>{const raw=Object.entries(localStorage).find(([k])=>k.endsWith('sauna.pausa.local.v1'))?.[1];if(!raw)return null;let value=JSON.parse(raw);if(typeof value==='string')value=JSON.parse(value);return value;});}
 try{
  await page.goto('http://127.0.0.1:8177/');await frame();
  await page.waitForFunction(()=>navigator.serviceWorker.controller!=null,{},{timeout:90000});
  await page.waitForFunction(async()=>{const urls=[];for(const name of await caches.keys())if(name.startsWith('stilo-public-'))for(const req of await(await caches.open(name)).keys())urls.push(req.url);return ['firebase-app','firebase-auth','firebase-firestore'].every(n=>urls.some(u=>u.includes(n)));},{},{timeout:60000});
  await context.setOffline(true);report.offline=true;
  for(const [title,kind]of [['Memorama Stilo','memory'],['Territorios Stilo','territory'],['Carrera Stilo','race']]){
   await page.reload({waitUntil:'domcontentloaded'});await frame();await lobby();
   // Flutter merges the game card and puts ChoiceChip values in aria-label, not DOM text.
   await page.getByText(title,{exact:false}).first().click();
   await page.getByLabel('4',{exact:true}).click();
   await page.getByRole('button',{name:'Empezar partida',exact:true}).click();
   await page.getByText(/P4 · Jugador 4/).waitFor();
   if(kind==='memory')await page.getByRole('button',{name:/Carta 1, oculta/}).first().click();
   if(kind==='territory')await page.getByRole('button',{name:/Horizontal 1: libre/}).first().click();
   if(kind==='race')await page.getByRole('button',{name:/Tirar dado/}).click();
   await page.getByText('Partida guardada en este dispositivo',{exact:true}).waitFor();
   const state=await stored();
   if(!state||state.kind!==kind||state.names.length!==4||!(kind==='memory'?state.first>=0:state.moves>0))throw Error('Four-player offline move was not persisted: '+JSON.stringify(state));
   await page.screenshot({path:`smoke-results/party-${kind}-offline.png`,fullPage:true});
   report.started.push({title,players:state.names.length,interacted:true,persisted:true,turn:state.turn,moves:state.moves,first:state.first});
  }
  const before=await stored();
  await page.reload({waitUntil:'domcontentloaded'});await frame();await lobby();
  await page.getByRole('button',{name:/Continuar · Carrera Stilo/}).click();
  await page.getByText(/P4 · Jugador 4/).waitFor();
  const after=await stored();if(JSON.stringify(before)!==JSON.stringify(after))throw Error('Resume changed the saved match.');report.resumed=true;
  if(report.errors.length)throw Error('Browser errors: '+report.errors.join('; '));
 }catch(error){report.failure=error.message;throw error;}
 finally{
  report.visibleText=await page.locator('body').innerText().catch(()=>'');
  report.accessibility=await page.locator('body').ariaSnapshot().catch(()=>'');
  report.savedGame=await stored().catch(()=>null);
  await page.screenshot({path:'smoke-results/party-last-state.png',fullPage:true}).catch(()=>{});
  fs.writeFileSync('smoke-results/party-offline.json',JSON.stringify(report,null,2));await browser.close();
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
