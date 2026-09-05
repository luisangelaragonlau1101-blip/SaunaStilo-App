/* No users, attendance records, or employee alerts are created by these checks. */
const {chromium} = require('playwright');
const fs = require('node:fs');
const base = process.env.SAUNA_URL || 'https://sauna-stilo-app-web.vercel.app/';
const guideUrl = 'https://ollin-smart-vxs23c.v2.appdeploy.ai/?workspace=sauna-stilo&role=trabajador';
const report=[];
(async () => {
  fs.mkdirSync('smoke-results', {recursive:true});
  const browser = await chromium.launch({headless:true, executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome', args:['--no-sandbox']});
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
      report.push({name,url:base,status:response.status(),firstFrame:true,visibleText:await page.locator('body').innerText(),errors});
      if(response.status()!==200 || errors.length) throw new Error('La aplicación reportó errores; revisa informe y capturas.');
      await page.close();
    }
    for (const name of ['updateAttendance','assignProjectActivity']) {
      try {
        const r=await fetch('https://us-central1-saunastiloapp-17e15.cloudfunctions.net/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({data:{}}),signal:AbortSignal.timeout(15000)});
        report.push({name,unauthenticatedHttpStatus:r.status,authenticatedFunctionalityTested:false});
      } catch(e) { report.push({name,error:e.name,authenticatedFunctionalityTested:false}); }
    }
    async function checkGuide(embedded) {
      const name=embedded?'online-smart-embedded':'online-smart-standalone';
      const result={name,realResponse:false,network:[],console:[],errors:[]};
      report.push(result);
      const page=await browser.newPage({viewport:{width:390,height:844}});
      page.on('pageerror',e=>result.errors.push(e.message.slice(0,300)));
      page.on('console',msg=>{if(['error','warning'].includes(msg.type()))result.console.push(msg.text().slice(0,300));});
      page.on('requestfailed',r=>result.network.push({url:r.url().split('?')[0],error:r.failure()?.errorText}));
      page.on('response',r=>{if(r.request().method()!=='GET'||r.status()>=400)result.network.push({url:r.url().split('?')[0],status:r.status()});});
      try {
        if(embedded) {
          await page.goto(base,{waitUntil:'domcontentloaded',timeout:60000});
          await page.evaluate(url=>{
            const f=document.createElement('iframe');f.id='sauna-guide-check';f.title='Online Smart, guía de Sauna Stilo';f.src=url;
            f.setAttribute('allow','microphone; autoplay');f.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-popups');f.setAttribute('referrerpolicy','no-referrer');
            f.style.cssText='position:fixed;inset:0;width:100%;height:100%;border:0;z-index:2147483647;background:#000';document.body.appendChild(f);
          },guideUrl);
        } else await page.goto(guideUrl,{waitUntil:'domcontentloaded',timeout:60000});
        const guide=embedded?page.frameLocator('#sauna-guide-check'):page;
        await guide.getByRole('textbox',{name:'Pregunta a Online Smart'}).fill('Preséntate y explica cómo encuentro mis tareas dentro de Sauna Stilo. No registres nada.');
        await guide.getByRole('button',{name:'Enviar pregunta',exact:true}).click();
        await Promise.race([
          guide.locator('.sg-bubble.assistant').last().waitFor({state:'visible',timeout:55000}),
          guide.locator('.sg-error').waitFor({state:'visible',timeout:55000}),
        ]);
        const answers=guide.locator('.sg-bubble.assistant');
        if(await answers.count()) {
          result.responseText=await answers.last().innerText();
          result.realResponse=result.responseText.length>60&&/Sauna\s*Stilo/i.test(result.responseText);
        }
        result.visibleText=await guide.locator('body').innerText();
      } catch(e) { result.errors.push(e.message.slice(0,500)); }
      finally {
        await page.screenshot({path:`smoke-results/${name}.png`,fullPage:true});
        const frame=page.frames().find(f=>f.url().includes('ollin-smart-vxs23c'));
        if(frame) result.visibleText=await frame.locator('body').innerText().catch(()=>result.visibleText||'');
        await page.close();
        console.log(JSON.stringify(result));
      }
      return result.realResponse;
    }
    if(!await checkGuide(true)) {
      await checkGuide(false);
      throw new Error('No se verificó una respuesta real dentro del iframe. El informe conserva el fallo y la comparación independiente.');
    }
  } finally { fs.writeFileSync('smoke-results/report.json',JSON.stringify(report,null,2));await browser.close(); }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
