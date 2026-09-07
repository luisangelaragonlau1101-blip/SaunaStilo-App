// Reads only local game/guest learning state. No employees, production documents or notifications.
const {chromium}=require('playwright'),fs=require('node:fs');
(async()=>{
 fs.mkdirSync('smoke-results',{recursive:true});
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:390,height:844}}),page=await context.newPage();
 const report={offline:false,rounds:false,english:false,french:false,recovered:false,privacy:false,errors:[]};
 page.on('pageerror',e=>report.errors.push(e.message));
 await page.addInitScript(()=>window.addEventListener('flutter-first-frame',()=>window.__stiloFrame=true));
 async function tap(target){
  await page.mouse.move(185,420);await page.mouse.wheel(0,-5000);await page.waitForTimeout(150);
  for(let n=0;n<18;n++){
   if(await target.count()){try{await target.click({timeout:1200});return;}catch(_){}}
   await page.mouse.wheel(0,260);await page.waitForTimeout(130);
  }
  throw Error('Target was not reachable through scrolling: '+target.toString());
 }
 async function frame(){await page.waitForFunction(()=>window.__stiloFrame===true,{},{timeout:60000});const node=page.locator('flt-semantics-placeholder');if(await node.count())await node.evaluate(n=>n.click());}
 async function lobby(){await page.getByRole('button',{name:'Juegos sin conexión · hasta 4',exact:true}).click();await page.getByText('ELIGE TU PAUSA',{exact:true}).waitFor();}
 async function readLocal(key){return page.evaluate(key=>{let raw=Object.entries(localStorage).find(([k])=>k.endsWith(key))?.[1];if(!raw)return null;let value=JSON.parse(raw);if(typeof value==='string')value=JSON.parse(value);return value;},key);}
 try{
  await page.goto('http://127.0.0.1:8177/');await frame();
  await page.waitForFunction(()=>navigator.serviceWorker.controller!=null,{},{timeout:90000});
  await page.waitForFunction(async()=>{const urls=[];for(const n of await caches.keys())if(n.startsWith('stilo-public-'))for(const r of await(await caches.open(n)).keys())urls.push(r.url);return ['firebase-app','firebase-auth','firebase-firestore','privacy-controls.js'].every(n=>urls.some(u=>u.includes(n)));},{},{timeout:60000});
  report.privacy=await page.evaluate(()=>{const c=new Event('copy',{bubbles:true,cancelable:true});document.dispatchEvent(c);const p=new Event('paste',{bubbles:true,cancelable:true});document.dispatchEvent(p);return c.defaultPrevented&&!p.defaultPrevented;});
  if(!report.privacy)throw Error('Copy prevention or paste preservation failed.');
  await context.setOffline(true);report.offline=true;await page.reload({waitUntil:'domcontentloaded'});await frame();await lobby();
  await page.getByRole('button',{name:'17 retos · Adivinanzas, quiz y más',exact:true}).click();
  await page.getByText('Adivinanzas',{exact:false}).first().click();
  await page.getByLabel('4 jugadores',{exact:true}).click();
  await page.getByRole('button',{name:'Comenzar partida',exact:true}).click();
  for(let n=0;n<12;n++){
   await tap(page.getByRole('button',{name:'Estoy listo',exact:true}));
   let state;for(let i=0;i<50;i++){state=await readLocal('sauna.rounds.local.v1');if(state?.ready&&state.index===n)break;await page.waitForTimeout(100);}
   if(!state?.ready||state.index!==n)throw Error('Turn not saved.');
   await tap(page.getByRole('button',{name:state.questions[n].answer,exact:true}));
   await tap(page.getByRole('button',{name:n===11?'Ver resultados':'Siguiente turno',exact:true}));
  }
  await page.getByText('¡Empate de campeones!',{exact:true}).waitFor();
  await page.screenshot({path:'smoke-results/academy-four-player-result.png',fullPage:true});
  const game=await readLocal('sauna.rounds.local.v1');if(game.index!==12||game.scores.some(n=>n!==30))throw Error('Wrong four-player round result.');report.rounds=true;
  for(const lang of ['en','fr']){
   await page.reload({waitUntil:'domcontentloaded'});await frame();await lobby();
   await page.getByRole('button',{name:'Probar idiomas · progreso de invitado',exact:true}).click();
   await page.getByLabel(lang==='en'?'Inglés':'Francés',{exact:true}).click();
   await page.getByText('1. Primeras palabras',{exact:false}).first().click();
   await page.screenshot({path:`smoke-results/academy-${lang}-lesson.png`,fullPage:true});
   await tap(page.getByRole('button',{name:'Practicar · 12 ejercicios',exact:true}));
   const entries=lang==='en'?{'Hello':'Hola','Goodbye':'Adiós','Thank you':'Gracias','Please':'Por favor','Yes':'Sí','No':'No'}:{'Bonjour':'Hola','Au revoir':'Adiós','Merci':'Gracias','S’il vous plaît':'Por favor','Oui':'Sí','Non':'No'};
   for(let n=0;n<12;n++){
    await page.mouse.move(185,420);await page.mouse.wheel(0,-5000);await page.waitForTimeout(150);
    const text=await page.locator('body').innerText();const match=text.match(/¿Qué significa «([^»]+)»\?|¿Cómo se dice «([^»]+)»/);
    if(!match)throw Error('Question not visible: '+text);
    const answer=match[1]?entries[match[1]]:Object.entries(entries).find(([,es])=>es===match[2])?.[0];if(!answer)throw Error('Unknown lesson prompt.');
    await tap(page.getByRole('button',{name:answer,exact:true}));
    await tap(page.getByRole('button',{name:n===11?'Terminar lección':'Continuar',exact:true}));
   }
   await page.getByText('¡Muy bien! Otro paso adelante.',{exact:true}).waitFor();
   await page.screenshot({path:`smoke-results/academy-${lang}-complete.png`,fullPage:true});
   const progress=await readLocal('sauna.learning.v1.local-guest');if(progress.scores[lang+'-1']!==100||progress.days[lang].length!==1)throw Error('Lesson result or streak was not saved.');
   report[lang==='en'?'english':'french']=true;
  }
  await page.reload({waitUntil:'domcontentloaded'});await frame();await lobby();await page.getByRole('button',{name:'Probar idiomas · progreso de invitado',exact:true}).click();
  await page.getByLabel('120 XP total',{exact:true}).waitFor();report.recovered=true;
  if(report.errors.length)throw Error(report.errors.join('\n'));
 }catch(e){report.failure=e.message;throw e;}
 finally{report.accessibility=await page.locator('body').ariaSnapshot().catch(()=>'');await page.screenshot({path:'smoke-results/academy-last.png',fullPage:true}).catch(()=>{});fs.writeFileSync('smoke-results/academy-qa.json',JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
