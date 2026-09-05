/* Browser checks never create users, register attendance, or send staff alerts. */
const {chromium} = require('playwright');
const fs = require('node:fs');
const base = process.env.SAUNA_URL || 'https://sauna-stilo-app-web.vercel.app/';
(async () => {
  fs.mkdirSync('smoke-results', {recursive:true});
  const browser = await chromium.launch({headless:true, executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome', args:['--no-sandbox']});
  const report=[];
  try {
    for (const [name, width, height] of [['phone',390,844],['desktop',1440,960]]) {
      const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
      const errors=[];page.on('pageerror',e=>errors.push(e.message));
      await page.addInitScript(()=>{window.addEventListener('flutter-first-frame',()=>{window.__saunaFrame=true;});});
      const response=await page.goto(base,{waitUntil:'domcontentloaded',timeout:60000});
      await page.waitForFunction(()=>window.__saunaFrame===true,{},{timeout:60000});
      await page.waitForTimeout(2500);
      const placeholder=page.locator('flt-semantics-placeholder');
      if (await placeholder.count()) await placeholder.evaluate(el=>el.click());
      await page.waitForTimeout(1500);
      await page.screenshot({path:`smoke-results/${name}.png`,fullPage:true});
      const text=await page.locator('body').innerText();
      report.push({name,url:base,status:response.status(),firstFrame:true,visibleText:text,errors});
      if(response.status()!==200 || errors.length) throw new Error('La aplicación reportó errores; revisa informe y capturas.');
      await page.close();
    }
    // Exercise the exact cross-origin iframe permissions from the shipped widget,
    // on the app origin, without bypassing or entering a Firebase session.
    const page=await browser.newPage({viewport:{width:390,height:844}});
    await page.goto(base,{waitUntil:'domcontentloaded',timeout:60000});
    await page.evaluate(() => {
      const frame=document.createElement('iframe');frame.id='sauna-guide-check';
      frame.title='Online Smart, guía de Sauna Stilo';
      frame.src='https://ollin-smart-vxs23c.v2.appdeploy.ai/?workspace=sauna-stilo&role=trabajador';
      frame.setAttribute('allow','microphone; autoplay');
      frame.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-popups');
      frame.setAttribute('referrerpolicy','no-referrer');
      frame.style.cssText='position:fixed;inset:0;width:100%;height:100%;border:0;z-index:2147483647;background:#000';
      document.body.appendChild(frame);
    });
    const guide=page.frameLocator('#sauna-guide-check');
    await guide.getByRole('textbox',{name:'Pregunta a Online Smart'}).fill('Preséntate y explica cómo encuentro mis tareas dentro de Sauna Stilo. No registres nada.');
    await guide.getByRole('button',{name:'Enviar pregunta',exact:true}).click();
    const answer=guide.locator('.sg-bubble.assistant').last();
    await answer.waitFor({state:'visible',timeout:60000});
    const responseText=await answer.innerText();
    if(responseText.length<60 || !/Sauna\s*Stilo/i.test(responseText)) throw new Error('La guía no devolvió una respuesta útil contextualizada.');
    await page.screenshot({path:'smoke-results/online-smart-embedded-phone.png',fullPage:true});
    report.push({name:'online-smart-embedded',realResponse:true,responseText});
    await page.close();
    for (const name of ['updateAttendance','assignProjectActivity']) {
      const r=await fetch('https://us-central1-saunastiloapp-17e15.cloudfunctions.net/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({data:{}}),signal:AbortSignal.timeout(15000)});
      report.push({name,unauthenticatedHttpStatus:r.status,authenticatedFunctionalityTested:false});
    }
  } finally { fs.writeFileSync('smoke-results/report.json',JSON.stringify(report,null,2));await browser.close(); }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
