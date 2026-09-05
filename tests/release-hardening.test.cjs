const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {retrieveWebContext}=require('../functions/web-grounding');

test('internal work queries do not need a public web search',()=>{
  const helper=fs.readFileSync('functions/assistant-v2.js','utf8');
  assert.match(helper,/needsPublicWeb/);
});

test('web request contains only the explicit question, no business history or records',async()=>{
  let call;
  const ai={models:{generateContent:async options=>{call=options;return{text:'web'}}}};
  const answer=await retrieveWebContext(ai,'model','Pregunta pública');
  assert.equal(answer,'web');
  assert.deepEqual(call.contents,[{role:'user',parts:[{text:'Pregunta pública'}]}]);
  assert.deepEqual(call.config.tools,[{googleSearch:{}}]);
  const privateCall=fs.readFileSync('functions/assistant-v2.js','utf8');
  assert.equal(privateCall.includes('config.tools ='),false);
});

test('all Flutter custom whites are valid explicit colors', () => {
  for(const file of ['futuristic_dashboard_screen.dart','voz_administracion_screen.dart']) assert.doesNotMatch(fs.readFileSync('lib/screens/'+file,'utf8'),/Colors\.white(?:48|78)\b/);
});

test('assistant falls back to real Online Smart rather than faking a response', () => {
  const service=fs.readFileSync('lib/services/ai_assistant_service.dart','utf8');
  assert.match(service,/ollin-smart-vxs23c\.v2\.appdeploy\.ai\/api\/chat/);
  assert.match(service,/_onlineSmartResponse/);
  assert.match(service,/workspace': 'sauna-stilo/);
  assert.doesNotMatch(service,/_responderLocal/);
  assert.match(fs.readFileSync('lib/screens/guia_inteligente_screen.dart','utf8'),/SIN CONSULTA A IA/);
});
