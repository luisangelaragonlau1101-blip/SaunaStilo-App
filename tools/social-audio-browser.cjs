const {chromium}=require('playwright');const fs=require('node:fs');
(async()=>{
 fs.mkdirSync('smoke-results',{recursive:true});
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});
 const results=[];
 try {
  for(const rate of [44100,48000]) {
   const page=await browser.newPage();await page.goto('http://127.0.0.1:8177/');await page.addScriptTag({path:'web/chat-audio-capture.js'});
   const result=await page.evaluate(async rate=>{
    const Native=window.AudioContext;window.AudioContext=class extends Native{constructor(){super({sampleRate:rate})}};
    const source=new Native({sampleRate:rate});await source.resume();const o=source.createOscillator();o.frequency.value=440;
    const dest=source.createMediaStreamDestination();o.connect(dest);o.start();
    const original=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);navigator.mediaDevices.getUserMedia=async()=>dest.stream;
    const capture=window.createSaunaChatAudioCapture();
    try {
     await capture.start(180);let rejected=false;try{await capture.start(180)}catch(_){rejected=true}
     await new Promise(r=>setTimeout(r,1600));
     const wav=await capture.stop(),h=new DataView(wav.buffer,wav.byteOffset,wav.byteLength);
     // Oscillator and capture contexts start independently. Leading silence is not a change of pitch.
     // Measure cycles over their actual sample interval; still require sufficient duration and playback.
     let crossings=0,last=0,firstCross=-1,lastCross=-1;
     for(let i=44;i<wav.length;i+=2){const v=h.getInt16(i,true);if(last<0&&v>=0){const sample=(i-44)/2;if(firstCross<0)firstCross=sample;lastCross=sample;crossings++;}last=v;}
     const activeSeconds=(lastCross-firstCross)/24000;
     const frequency=activeSeconds>0?(crossings-1)/activeSeconds:0;
     const seconds=(wav.length-44)/48000;const audio=new Audio(URL.createObjectURL(new Blob([wav],{type:'audio/wav'})));
     await new Promise((resolve,reject)=>{audio.onloadedmetadata=resolve;audio.onerror=reject;});await audio.play();await new Promise(r=>setTimeout(r,250));
     const advanced=audio.currentTime>0;audio.pause();URL.revokeObjectURL(audio.src);
     return {input:rate,output:h.getUint32(24,true),seconds,activeSeconds,frequency,duplicateStartRejected:rejected,playbackAdvanced:advanced,tracksStopped:dest.stream.getTracks().every(t=>t.readyState==='ended')};
    } finally {navigator.mediaDevices.getUserMedia=original;window.AudioContext=Native;o.stop();await source.close();await capture.dispose();}
   },rate);
   results.push(result);if(result.output!==24000||result.seconds<1||result.seconds>2||result.activeSeconds<0.8||Math.abs(result.frequency-440)>5||!result.playbackAdvanced||!result.tracksStopped||!result.duplicateStartRejected)throw Error('Audio capture/playback contract failed');
   await page.close();
  }
  const page=await browser.newPage({viewport:{width:390,height:844}});
  // Same-origin harness validates child-to-parent handoff without Firebase or staff data.
  await page.route('**/social-voice-harness.html',route=>route.fulfill({contentType:'text/html',body:`<body style="margin:0"><iframe title="guide" style="width:100%;height:800px;border:0" src="https://ollin-smart-vxs23c.v2.appdeploy.ai/?workspace=sauna-stilo&voiceParent=http%3A%2F%2F127.0.0.1%3A8177"></iframe><script>window.received=[];window.addEventListener('message',e=>{if(e.origin==='https://ollin-smart-vxs23c.v2.appdeploy.ai')window.received.push(e.data)});</script></body>`}));
  await page.goto('http://127.0.0.1:8177/social-voice-harness.html');const frame=page.frameLocator('iframe');
  await frame.getByRole('textbox',{name:'Pregunta a Online Smart'}).fill('Saluda al equipo de Sauna Stilo en una oración.');await frame.getByRole('button',{name:'Enviar pregunta',exact:true}).click();
  await frame.getByRole('button',{name:'Solicitar voz de Ángel'}).waitFor({timeout:60000});
  await frame.getByRole('button',{name:'Solicitar voz de Ángel'}).click();await page.waitForFunction(()=>window.received.length>0);
  const data=JSON.parse(await page.evaluate(()=>window.received[0]));
  if(data.channel!=='sauna-voice-v1'||data.event!=='request'||!data.text||Object.keys(data).length!==3)throw Error('Voice bridge contract');
  results.push({voiceBridge:'passed',generatedReplyCharacters:data.text.length,credentialsForwarded:false});
  await page.screenshot({path:'smoke-results/social-guide-voice.png'});
 } finally {fs.writeFileSync('smoke-results/social-audio-check.json',JSON.stringify(results,null,2));await browser.close();}
 console.log(JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
