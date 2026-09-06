const test=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,runTransaction,Timestamp}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
let env;
test.before(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_STORAGE_EMULATOR_HOST)throw Error('Only isolated emulators may run this test.');
 // Storage firestore.get resolves against the emulator project's Firestore database.
 // Use the CLI's demo project, run suites sequentially, and reset fixtures explicitly.
 env=await initializeTestEnvironment({projectId:'demo-sauna-team',firestore:{rules:fs.readFileSync('firestore.rules','utf8')},storage:{rules:fs.readFileSync('storage.rules','utf8')}});
 await env.clearFirestore();
 await env.clearStorage();
 await env.withSecurityRulesDisabled(async c=>{
  for(const [id,rol]of [['admin','admin'],['warehouse','almacenista'],['worker','trabajador'],['other','trabajador']])await setDoc(doc(c.firestore(),'usuarios',id),{nombre:id,correo:id+'@example.invalid',rol});
 });
});
test.after(async()=>{if(env)await env.cleanup()});
test('workers edit their own optional interests, never awards or another person',async()=>{
 const db=env.authenticatedContext('worker').firestore();
 await assertSucceeds(updateDoc(doc(db,'usuarios','worker'),{intereses:'Música',coloresFavoritos:'Verde'}));
 await assertFails(updateDoc(doc(db,'usuarios','worker'),{insigniasAdmin:[{nombre:'Autopremio'}]}));
 await assertFails(updateDoc(doc(db,'usuarios','worker'),{lugaresInstalacion:[{nombre:'Falso'}]}));
 await assertFails(updateDoc(doc(db,'usuarios','other'),{intereses:'Cambio ajeno'}));
 await assertFails(updateDoc(doc(db,'usuarios','worker'),{intereses:'x'.repeat(401)}));
});
test('administration grants manual awards and places',async()=>{
 const db=env.authenticatedContext('admin').firestore();
 await assertSucceeds(updateDoc(doc(db,'usuarios','worker'),{insigniasAdmin:[{nombre:'Calidad',detalle:'Trabajo revisado'}],lugaresInstalacion:[{nombre:'La Paz, BCS'}]}));
});
test('first justification can be created transactionally, no false hours',async()=>{
 const db=env.authenticatedContext('worker').firestore();const r=doc(db,'asistencias','worker_20260905');
 await assertSucceeds(runTransaction(db,async t=>{const d=await t.get(r);if(!d.exists())t.set(r,{id:r.id,trabajadorId:'worker',fecha:Timestamp.fromDate(new Date('2026-09-05T18:00:00Z')),estatus:'falta',estatusComida:'ninguna',ubicacionValida:false,motivoFalta:'Motivo privado',estatusJustificacion:'pendiente_revision'});}));
 await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'asistencias','worker_20260905')));
 await assertFails(updateDoc(r,{horaEntrada:Timestamp.now()}));
});
test('approved justifications cannot be reopened by workers',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'asistencias','worker_20260904'),{trabajadorId:'worker',estatusJustificacion:'aprobada',motivoFalta:'Ya revisado'}));
 await assertFails(updateDoc(doc(env.authenticatedContext('worker').firestore(),'asistencias','worker_20260904'),{estatusJustificacion:'pendiente_revision',motivoFalta:'Cambiar'}));
});
test('private evidence denies peers even though legacy and social media remain readable',async()=>{
 const path='justification_evidence/worker/day/evidence.png';
 await assertSucceeds(uploadBytes(ref(env.authenticatedContext('worker').storage(),path),new Uint8Array([137,80,78,71]),{contentType:'image/png'}));
 await assertSucceeds(getBytes(ref(env.authenticatedContext('worker').storage(),path)));
 await assertSucceeds(getBytes(ref(env.authenticatedContext('admin').storage(),path)));
 await assertFails(getBytes(ref(env.authenticatedContext('other').storage(),path)));
 await assertFails(getBytes(ref(env.unauthenticatedContext().storage(),path)));
 await assertFails(uploadBytes(ref(env.authenticatedContext('other').storage(),path),new Uint8Array([1]),{contentType:'image/png'}));
});
test('only administration and warehouse register inventory photos',async()=>{
 const bytes=new Uint8Array([137,80,78,71]);
 await assertSucceeds(uploadBytes(ref(env.authenticatedContext('admin').storage(),'insumos_inventario/admin.png'),bytes,{contentType:'image/png'}));
 await assertSucceeds(uploadBytes(ref(env.authenticatedContext('warehouse').storage(),'insumos_inventario/warehouse.png'),bytes,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(env.authenticatedContext('worker').storage(),'insumos_inventario/worker.png'),bytes,{contentType:'image/png'}));
 await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(),'insumos_inventario/visitor.png'),bytes,{contentType:'image/png'}));
});
