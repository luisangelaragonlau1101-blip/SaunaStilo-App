/* Read-only production smoke test. Never creates users or submits credentials. */
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
      if(response.status()!==200 || errors.length) throw new Error('La aplicación reportó errores; revisa el informe y las capturas.');
      await page.close();
    }
  } finally { fs.writeFileSync('smoke-results/report.json',JSON.stringify(report,null,2));await browser.close(); }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
