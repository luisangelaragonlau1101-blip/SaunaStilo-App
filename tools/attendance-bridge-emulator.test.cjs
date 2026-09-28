'use strict';
const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, collection, query, where, documentId, setDoc, getDocs, getDoc, updateDoc, Timestamp} = require('firebase/firestore');
let env;
before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(localhost|127\.0\.0\.1):\d+$/);
  env = await initializeTestEnvironment({projectId:'demo-sauna-attendance-bridge', firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  await env.withSecurityRulesDisabled(async c => {
    for (const [uid, rol] of [['admin','admin'],['worker','trabajador'],['other','trabajador']]) await setDoc(doc(c.firestore(),'usuarios',uid),{nombre:uid,rol,activo:true});
  });
});
after(async () => { if(env) await env.cleanup(); });
test('ownership plus document-name query can read the first empty day under unchanged production rules', async () => {
  const worker = env.authenticatedContext('worker').firestore();
  const q = query(collection(worker,'asistencias'), where('trabajadorId','==','worker'), where(documentId(),'==','worker_20260928'));
  const empty = await assertSucceeds(getDocs(q)); assert.equal(empty.size,0);
  await assertFails(setDoc(doc(worker,'asistencias','worker_20260928'),{trabajadorId:'worker',horaEntrada:Timestamp.now()}));
  const admin = env.authenticatedContext('admin').firestore();
  await assertSucceeds(setDoc(doc(admin,'asistencias','worker_20260928'),{trabajadorId:'worker',horaEntrada:Timestamp.now(),listaBonos:[{monto:100}],observacionesAdmin:'Conservar'}));
  assert.equal((await assertSucceeds(getDocs(q))).size,1);
  await assertFails(getDocs(query(collection(env.authenticatedContext('other').firestore(),'asistencias'),where('trabajadorId','==','worker'),where(documentId(),'==','worker_20260928'))));
  await assertSucceeds(updateDoc(doc(admin,'asistencias','worker_20260928'),{horaSalida:Timestamp.now(),movimientosServidor:{horaSalida:'receipt-only'}}));
  const saved = (await getDoc(doc(worker,'asistencias','worker_20260928'))).data();
  assert.deepEqual(saved.listaBonos,[{monto:100}]); assert.equal(saved.observacionesAdmin,'Conservar');
});
