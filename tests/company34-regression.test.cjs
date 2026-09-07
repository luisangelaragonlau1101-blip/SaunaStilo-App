const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const read=p=>fs.readFileSync(p,'utf8');
test('home has work progress only and local lobby has only original boards',()=>{
 assert.doesNotMatch(read('lib/widgets/home_progress_panel.dart'),/home-learn|Continuar aprendiendo|XP idiomas/);
 assert.doesNotMatch(read('lib/screens/local_party_screen.dart'),/RoundArcadeScreen|StiloAcademyScreen|17 retos/);
 const catalog=read('lib/services/app_action_catalog.dart');assert.match(catalog,/TrainingAccessScreen\(user:\s*user\)/);assert.match(catalog,/conocimiento_ia/);
});
test('session is sent only in a secure header, never in iframe or manual generation prompt',()=>{
 const client=read('lib/services/company_learning_service.dart');assert.match(client,/X-Sauna-Token/);assert.match(client,/getIdToken/);
 assert.doesNotMatch(read('lib/screens/online_smart_screen.dart'),/getIdToken|X-Sauna-Token/);
 const api=read('tools/online-smart34/sauna-service.mjs');assert.match(api,/accounts:lookup/);assert.match(api,/validSince/);assert.match(api,/fields\|\|\{\}/);assert.match(api,/manual-publish/);
});
test('alarm reuses create-only push and unchanged urgent sound rather than sending a new alarm during QA',()=>{
 const screen=read('lib/screens/admin_alerta_general_screen.dart');assert.match(screen,/batch.commit/);assert.match(screen,/_pending/);assert.match(screen,/_batchId/);
 assert.match(read('lib/widgets/avisos_sonoros.dart'),/sounds\/urgent_alarm\.ogg/);
 const payload=read('lib/services/personalized_alert.dart');assert.match(payload,/tipo':'alarma_admin'/);assert.match(payload,/audience=='personas'/);
});
