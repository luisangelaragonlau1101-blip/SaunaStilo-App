const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { decodeVoiceWav } = require('../functions/voice-audio');
const { retrieveWebContext, needsPublicSearch } = require('../functions/web-context');
class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
function sample(seconds=3) {
  const b = Buffer.alloc(44 + seconds * 48000); b.write('RIFF'); b.writeUInt32LE(b.length-8,4); b.write('WAVE',8); b.write('fmt ',12); b.writeUInt32LE(16,16); b.writeUInt16LE(1,20); b.writeUInt16LE(1,22); b.writeUInt32LE(24000,24); b.writeUInt32LE(48000,28); b.writeUInt16LE(2,32); b.writeUInt16LE(16,34); b.write('data',36); b.writeUInt32LE(b.length-44,40); return b;
}
test('voice accepts valid bounded mono PCM WAV and rejects short recordings', () => {
  assert.equal(decodeVoiceWav(sample(3).toString('base64'), HttpsError).length, 144044);
  assert.equal(decodeVoiceWav(sample(10).toString('base64'), HttpsError).length, 480044);
  assert.throws(() => decodeVoiceWav(sample(1).toString('base64'), HttpsError), {code:'invalid-argument'});
});
test('voice rejects stereo, incorrect duration and non-audio before provider calls', () => {
  const stereo=sample();stereo.writeUInt16LE(2,22);
  for(const s of [stereo.toString('base64'), sample(11).toString('base64'), 'not valid audio', null]) assert.throws(()=>decodeVoiceWav(s,HttpsError),{code:'invalid-argument'});
});
test('voice rejects forged WAV header length and wrong sample rate', () => {
  const wrong=sample();wrong.writeUInt32LE(16000,24);
  assert.throws(()=>decodeVoiceWav(wrong.toString('base64'),HttpsError),{code:'invalid-argument'});
  const wrongLength=sample();wrongLength.writeUInt32LE(2,40);
  assert.throws(()=>decodeVoiceWav(wrongLength.toString('base64'),HttpsError),{code:'invalid-argument'});
});
test('voice enrollment no longer sends samples to shared Storage', () => {
  const screen=fs.readFileSync('lib/screens/voz_administracion_screen.dart','utf8');
  assert.equal(screen.includes('_media.upload'),false);
  assert.match(screen,/consentBase64: base64Encode/);
  assert.match(fs.readFileSync('functions/app.js','utf8'),/decodeVoiceWav/);
});
test('internal work queries do not need a public web search', () => {
  for(const q of ['Mis pendientes','Resumen ejecutivo','Proyectos y estados','Cotizaciones','¿Qué herramientas hay en inventario?']) assert.equal(needsPublicSearch(q),false);
  assert.equal(needsPublicSearch('Busca en Internet las noticias de hoy'),true);
});
test('web request contains only the explicit question, no business history or records', async () => {
  let call;const answer={text:'Public facts'};
  const ai={models:{generateContent:async q=>{call=q;return answer;}}};
  assert.equal(await retrieveWebContext(ai,'model','Pregunta pública'),answer);
  assert.deepEqual(call.contents,[{role:'user',parts:[{text:'Pregunta pública'}]}]);
  assert.deepEqual(call.config.tools,[{googleSearch:{}}]);
  const privateCall=fs.readFileSync('functions/assistant-v2.js','utf8');
  assert.equal(privateCall.includes('config.tools ='),false);
});
test('all Flutter custom whites are valid explicit colors', () => {
  for(const file of ['futuristic_dashboard_screen.dart','voz_administracion_screen.dart']) assert.doesNotMatch(fs.readFileSync('lib/screens/'+file,'utf8'),/Colors\.white(?:48|78)\b/);
});
test('assistant service still identifies absent backend rather than faking a response', () => {
  assert.match(fs.readFileSync('lib/services/ai_assistant_service.dart','utf8'),/not-found/);
  assert.match(fs.readFileSync('lib/screens/guia_inteligente_screen.dart','utf8'),/SIN CONSULTA A IA/);
});
