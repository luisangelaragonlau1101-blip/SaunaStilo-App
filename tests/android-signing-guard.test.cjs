const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
test('Android release never silently falls back to the ephemeral debug signing key',()=>{
 const gradle=fs.readFileSync('android/app/build.gradle.kts','utf8');
 assert(!/signingConfigs\.getByName\("debug"\)/.test(gradle));
 assert(gradle.includes('throw GradleException'));
 for(const name of ['SAUNA_SIGNING_STORE','SAUNA_SIGNING_PASSWORD','SAUNA_SIGNING_ALIAS'])assert(gradle.includes(name));
});
test('Android release is deliberate, needs protected secrets, verifies fingerprint, and cleans the key',()=>{
 const workflow=fs.readFileSync('.github/workflows/build-apk.yml','utf8');
 assert(workflow.includes('workflow_dispatch:'));assert(!/^\s+push:/m.test(workflow));
 for(const value of ['secrets.ANDROID_KEYSTORE_BASE64','secrets.ANDROID_KEYSTORE_PASSWORD','vars.ANDROID_CERT_SHA256','actual!={expected}','if: always()'])assert(workflow.includes(value));
 assert(!fs.existsSync('.github/workflows/android-recovery.yml'),'One-time key generation must not remain triggered.');
});
test('Recovery proof states separate identity and does not promise data migration or real-account tests',()=>{
 const r=JSON.parse(fs.readFileSync('ANDROID_RECOVERY_VERIFIED.json','utf8'));
 assert.notEqual(r.applicationId,r.legacyApplicationId);
 assert.equal(r.installationTest.recoveryInstalledWithoutUninstall,true);
 assert.equal(r.localOnlyDataAutomaticallyMigrated,false);
 assert.equal(r.realAccountSignInTested,false);
 assert.equal(r.githubSigningSecretsConfigured,false);
 assert.match(r.apkSha256,/^[0-9a-f]{64}$/);
});
