const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
test('company actions keep the authenticated API contract and local fallbacks',()=>{
 const s=fs.readFileSync('lib/services/company_learning_service.dart','utf8');
 assert.ok(s.includes('https://api-v2.appdeploy.ai/app/ollin-smart-vxs23c/api/sauna'));
 assert.ok(s.includes('https://ollin-smart-vxs23c.v2.appdeploy.ai/api/sauna'));
 assert.ok(s.includes("'X-Sauna-Token'"));
 assert.ok(s.includes('getIdToken'));
 assert.ok(s.includes('currentUser?.uid != user.uid'));
 assert.ok(s.includes('FirestoreDailyTasksService'));
 assert.ok(s.includes('LocalAttendanceFallback'));
 assert.ok(!s.includes('Este servicio está temporalmente pausado. Intenta más tarde; no se confirmó esta operación.'));
});
