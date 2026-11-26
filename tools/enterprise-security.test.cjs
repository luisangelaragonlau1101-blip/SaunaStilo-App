const test=require('node:test'),fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,serverTimestamp}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
let env;
test.before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_STORAGE_EMULATOR_HOST)throw Error('Isolated Firestore and Storage required');
  env=await initializeTestEnvironment({projectId:'demo-sauna-team',firestore:{rules:fs.readFileSync('firestore.rules','utf8')},storage:{rules:fs.readFileSync('storage.rules','utf8')}});
  await env.clearFirestore();await env.clearStorage();
  await env.withSecurityRulesDisabled(async c=>{
    const db=c.firestore();
    for(const [id,rol,permisosEmpresa,activo] of [['admin','admin',[],true],['finance','contabilidad',[],true],['buyer','trabajador',['solicitarCompras'],true],['worker','trabajador',[],true],['inactive','admin',[],false]])
      await setDoc(doc(db,'usuarios',id),{rol,activo,permisosEmpresa});
    await setDoc(doc(db,'gestion_movimientos','private'),{tipo:'ingreso',centavos:10000,schemaVersion:2026});
    await setDoc(doc(db,'notificaciones','private_purchase'),{destinatarioId:'worker',rolesDestinatarios:[],privadoCompras:true,leidosPor:[]});
    await setDoc(doc(db,'instalacion_ordenes','private'),{participantes:['buyer'],estado:'borrador'});
  });
});
test.after(async()=>{if(env)await env.cleanup();});
test('financial ledger reads respect capabilities and client writes cannot bypass server transactions',async()=>{
  for(const actor of ['admin','finance'])await assertSucceeds(getDoc(doc(env.authenticatedContext(actor).firestore(),'gestion_movimientos','private')));
  for(const actor of ['worker','buyer','inactive'])await assertFails(getDoc(doc(env.authenticatedContext(actor).firestore(),'gestion_movimientos','private')));
  await assertFails(getDoc(doc(env.authenticatedContext('worker').firestore(),'notificaciones','private_purchase')));
  await assertFails(updateDoc(doc(env.authenticatedContext('admin').firestore(),'gestion_movimientos','private'),{centavos:1}));
  await assertFails(setDoc(doc(env.authenticatedContext('buyer').firestore(),'usuarios','buyer'),{rol:'admin',permisosEmpresa:['finanzas']}));
});
test('tickets are immutable and private to their uploader and financial readers',async()=>{
  const path='finance/buyer/receipt/ticket.jpg',bytes=new Uint8Array([255,216,255,217]);
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext('buyer').storage(),path),bytes,{contentType:'image/jpeg'}));
  for(const actor of ['buyer','admin','finance'])await assertSucceeds(getBytes(ref(env.authenticatedContext(actor).storage(),path)));
  for(const actor of ['worker','inactive'])await assertFails(getBytes(ref(env.authenticatedContext(actor).storage(),path)));
  await assertFails(uploadBytes(ref(env.authenticatedContext('buyer').storage(),path),bytes,{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('worker').storage(),'finance/worker/receipt/forged.jpg'),bytes,{contentType:'image/jpeg'}));
});
test('installation records and signed documents are limited to authorized identities',async()=>{
  await env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(),'instalaciones/private/actas/salida.pdf'),new Uint8Array([37,80,68,70]),{contentType:'application/pdf'}));
  for(const actor of ['admin','buyer']){
    await assertSucceeds(getDoc(doc(env.authenticatedContext(actor).firestore(),'instalacion_ordenes','private')));
    await assertSucceeds(getBytes(ref(env.authenticatedContext(actor).storage(),'instalaciones/private/actas/salida.pdf')));
  }
  for(const actor of ['worker','finance','inactive'])await assertFails(getBytes(ref(env.authenticatedContext(actor).storage(),'instalaciones/private/actas/salida.pdf')));
  await assertFails(updateDoc(doc(env.authenticatedContext('admin').firestore(),'instalacion_ordenes','private'),{estado:'cerrada'}));
});
test('preferences are personal and inactive accounts cannot access general employee data',async()=>{
  await assertSucceeds(setDoc(doc(env.authenticatedContext('worker').firestore(),'preferencias_notificaciones','worker'),{jornada:false,actualizadoEn:serverTimestamp()}));
  await assertFails(getDoc(doc(env.authenticatedContext('buyer').firestore(),'preferencias_notificaciones','worker')));
  await assertFails(getDoc(doc(env.authenticatedContext('inactive').firestore(),'usuarios','worker')));
});


test('an authenticated account without an employee profile cannot inspect coworkers or private files',async()=>{
 const pending=env.authenticatedContext('unprovisioned');
 await assertSucceeds(getDoc(doc(pending.firestore(),'usuarios','unprovisioned')));
 await assertFails(getDoc(doc(pending.firestore(),'usuarios','worker')));
 await assertFails(getDoc(doc(pending.firestore(),'gestion_movimientos','private')));
 await assertFails(getBytes(ref(pending.storage(),'finance/buyer/receipt/ticket.jpg')));
});
