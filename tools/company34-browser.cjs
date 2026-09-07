// Read-only anonymous acceptance. No employee account, grant, manual or alarm is created.
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
  // Read the same endpoint as the app, preventing the test from drifting to a different server.
  const service=fs.readFileSync('lib/services/company_learning_service.dart','utf8');
  const endpoint=service.match(/Uri\.parse\('([^']+)'\)/)?.[1];
  if(!endpoint||!endpoint.startsWith('https://api-v2.appdeploy.ai/app/ollin-smart-vxs23c/'))throw Error('Unexpected service transport');
  const origin='https://sauna-stilo-app-web.vercel.app';
  const denied=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify({action:'manual-list'}),signal:AbortSignal.timeout(15000)});
  report.unauthenticatedStatus=denied.status;report.cors=denied.headers.get('access-control-allow-origin');
  const denial=await denied.json();
  if(denied.status!==401||!denial.error||denial.items)throw Error('Private service did not return an authenticated denial');
  const preflight=await fetch(endpoint,{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Headers':'x-sauna-token,content-type','Access-Control-Request-Method':'POST'},signal:AbortSignal.timeout(15000)});
  report.preflightStatus=preflight.status;report.preflightHeaders=preflight.headers.get('access-control-allow-headers');
  if(!preflight.ok||!report.preflightHeaders?.toLowerCase().includes('x-sauna-token'))throw Error('App session preflight is unavailable');
  // This browser-only origin fixture contains no app state or real credentials.
  const probe=await browser.newPage();await probe.route(origin+'/read-only-service-check',r=>r.fulfill({contentType:'text/html',body:'<title>Anonymous session check</title>'}));
  await probe.goto(origin+'/read-only-service-check');
  report.browserDenied=await probe.evaluate(async url=>{const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json','X-Sauna-Token':'invalid-test-session'},body:JSON.stringify({action:'manual-list'})});const j=await r.json();return{status:r.status,denied:!!j.error,leakedItems:!!j.items};},endpoint);
  if(report.browserDenied.status!==401||!report.browserDenied.denied||report.browserDenied.leakedItems)throw Error('Browser session boundary failed');
  await probe.close();if(report.errors.length)throw Error('Browser errors occurred');
 }catch(e){report.failure=e.message;throw e;}
 finally{fs.writeFileSync('smoke-results/company34-check.json',JSON.stringify(report,null,2));await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
