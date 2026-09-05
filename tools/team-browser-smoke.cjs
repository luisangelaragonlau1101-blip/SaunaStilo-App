const fs=require('node:fs');
const {chromium}=require('playwright');
(async()=>{
 fs.mkdirSync('smoke-results',{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/google-chrome',args:['--no-sandbox']});
 const report={guide:{},publicServices:{},scope:'No production team notifications or attendance writes were sent'};
 try {
  const page=await browser.newPage({viewport:{width:390,height:844}});
  const guide='https://ollin-smart-vxs23c.v2.appdeploy.ai/?workspace=sauna-stilo&role=trabajador';
  await page.goto(guide,{waitUntil:'domcontentloaded',timeout:45000});
  await page.getByLabel('Pregunta a Online Smart').fill('¿Cómo encuentro mis tareas en Sauna Stilo?');
  await page.getByRole('button',{name:'Enviar pregunta',exact:true}).click();
  await page.locator('.sg-bubble.assistant').first().waitFor({timeout:65000});
  const text=await page.locator('.sg-bubble.assistant').first().innerText();
  if(text.length<30)throw Error('Guide did not produce useful text');
  report.guide={answered:true,text};
  await page.screenshot({path:'smoke-results/online-smart-answer.png',fullPage:true});
  await page.getByLabel('Nueva conversación').click();
  if(await page.locator('.sg-bubble').count())throw Error('Conversation reset failed');
  // Test that embedding is actually permitted, not just the standalone URL.
  await page.goto(process.env.SAUNA_URL||'http://127.0.0.1:8177/',{waitUntil:'domcontentloaded'});
  await page.evaluate(url=>{const f=document.createElement('iframe');f.id='embedding-check';f.src=url;f.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-popups');f.setAttribute('allow','microphone; autoplay');f.setAttribute('referrerpolicy','no-referrer');f.style='position:fixed;inset:0;width:100%;height:100%;z-index:999999;background:black';document.body.appendChild(f)},guide);
  await page.frameLocator('#embedding-check').getByLabel('Pregunta a Online Smart').waitFor({timeout:30000});
  report.guide.embedded=true;
  for(const name of ['updateAttendance','saunaAssistantV2']) {
   const response=await fetch('https://us-central1-saunastiloapp-17e15.cloudfunctions.net/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:'{"data":{}}',signal:AbortSignal.timeout(15000)});
   report.publicServices[name]=response.status;
  }
 } finally { fs.writeFileSync('smoke-results/team-workflow-report.json',JSON.stringify(report,null,2)); await browser.close(); }
})().catch(e=>{console.error(e.message);process.exitCode=1});
