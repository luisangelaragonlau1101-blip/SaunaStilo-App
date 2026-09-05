/* Real Web Audio processing, synthetic microphone. No voices, accounts or staff messages. */
const {chromium}=require('playwright');const fs=require('node:fs');
(async()=>{
 fs.mkdirSync('smoke-results',{recursive:true});
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});
 const results=[];
 try{
  for(const rate of [44100,48000]){
   const page=await browser.newPage();await page.goto('http://127.0.0.1:8177/');
   await page.addScriptTag({path:'web/voice-capture.js'});
   const result=await page.evaluate(async rate=>{
    const Native=window.AudioContext;
    window.AudioContext=class extends Native{constructor(){super({sampleRate:rate})}};
    const source=new Native({sampleRate:rate});await source.resume();
    const oscillator=source.createOscillator();oscillator.frequency.value=440;
    const dest=source.createMediaStreamDestination();oscillator.connect(dest);oscillator.start();
    const original=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    navigator.mediaDevices.getUserMedia=async()=>dest.stream;
    try{
     await window.saunaVoiceCapture.start(10);
     await new Promise(resolve=>setTimeout(resolve,3500));
     const wav=await window.saunaVoiceCapture.stop();const v=new DataView(wav.buffer,wav.byteOffset,wav.byteLength);
     let crossings=0,prev=0;for(let i=44;i<wav.length;i+=2){const x=v.getInt16(i,true);if(prev<0&&x>=0)crossings++;prev=x;}
     const seconds=(wav.length-44)/48000;return {inputRate:rate,outputRate:v.getUint32(24,true),seconds,frequency:crossings/seconds,tracksStopped:dest.stream.getTracks().every(t=>t.readyState==='ended')};
    }finally{navigator.mediaDevices.getUserMedia=original;window.AudioContext=Native;oscillator.stop();await source.close();await window.saunaVoiceCapture.dispose();}
   },rate);
   results.push(result);
   if(result.outputRate!==24000||result.seconds<3||result.seconds>4.5||Math.abs(result.frequency-440)>10||!result.tracksStopped)throw Error('Audio rate, pitch, duration or microphone release failed.');
   await page.close();
  }
 }finally{fs.writeFileSync('smoke-results/voice-rate-check.json',JSON.stringify(results,null,2));await browser.close();}
 console.log(JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
