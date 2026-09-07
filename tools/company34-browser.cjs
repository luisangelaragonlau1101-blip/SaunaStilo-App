// Read-only public/anonymous checks. No staff accounts, enrollment, manual or alert is created.
const {chromium}=require('playwright');const fs=require('node:fs');
(async()=>{
 fs.mkdirSync('smoke-results',{recursive:true});
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:390,height:844}});const report={errors:[]};
 page.on('pageerror',e=>report.errors.push(e.message));
 await page.addInitScript(()=>window.addEventListener('flutter-first-frame',()=>window.__frame=true));
 try{
  await page.goto('http://127.0.0.1:8177/');await page.waitForFunction(()=>window.__frame===true,{},{timeout:60000});
  const semantics=page.locator('flt-semantics-placeholder');if(await semantics.count())await semantics.evaluate(el=>el.click());
  const entry=page.getByRole('button',{name:'Juegos sin conexión · hasta 4',exact:true});await entry.waitFor({timeout:30000});await entry.click();
  await page.getByText('ELIGE TU PAUSA',{exact:true}).waitFor();
  const visible=await page.locator('body').innerText();
  if(/17 retos|Adivinanzas, quiz|Continuar aprendiendo|Stilo Aprende/.test(visible))throw Error('Removed guest features remain visible');
  report.guestArcadeRemoved=true;report.guestLanguagesRemoved=true;
  for(const name of ['Memorama Stilo','Territorios Stilo','Carrera Stilo'])await page.getByText(name,{exact:false}).first().waitFor();
  report.boardsRetained=3;
  await page.screenshot({path:'smoke-results/company34-games.png',fullPage:true});
  const endpoint='https://ollin-smart-vxs23c.v2.appdeploy.ai/api/sauna';
  const denied=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json','Origin':'https://sauna-stilo-app-web.vercel.app'},body:JSON.stringify({action:'manual-list'}),signal:AbortSignal.timeout(15000)});
  report.unauthenticatedStatus=denied.status;
  report.cors=denied.headers.get('access-control-allow-origin');
  if(denied.status!==401)throw Error('Private service did not deny an anonymous call');
  const preflight=await fetch(endpoint,{method:'OPTIONS',headers:{'Origin':'https://sauna-stilo-app-web.vercel.app','Access-Control-Request-Headers':'x-sauna-token,content-type','Access-Control-Request-Method':'POST'},signal:AbortSignal.timeout(15000)});
  report.preflightStatus=preflight.status;report.preflightHeaders=preflight.headers.get('access-control-allow-headers');
  if(!preflight.ok||!report.preflightHeaders?.toLowerCase().includes('x-sauna-token'))throw Error('Authorized app cannot make a session request');
  if(report.errors.length)throw Error('Browser errors occurred');
 }finally{fs.writeFileSync('smoke-results/company34-check.json',JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
