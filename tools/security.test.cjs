const test=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,collection,query,where,or,updateDoc,serverTimestamp,Timestamp}=require('firebase/firestore');
let env;
test.before(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Only emulator may run this test.');
 env=await initializeTestEnvironment({projectId:'demo-sauna-team',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  for(const [id,rol]of [['admin','admin'],['master','maestro'],['worker','trabajador'],['outside','trabajador']])await setDoc(doc(db,'usuarios',id),{nombre:id,correo:id+'@example.invalid',rol});
  await setDoc(doc(db,'proyectos','own'),{encargados:['master','worker'],titulo:'Propio'});
  await setDoc(doc(db,'proyectos','other'),{encargados:['outside'],titulo:'Ajeno'});
 });
});
test.after(async()=>{if(env)await env.cleanup()});
const task=(proyectoId='own',assignee='worker')=>({proyectoId,titulo:'Tarea',descripcion:'Actividad de prueba',asignadoATrabajadorId:assignee,fechaInicio:Timestamp.fromMillis(100000),fechaTermino:Timestamp.fromMillis(200000),fechaAsignada:Timestamp.fromMillis(100000),completadoEn:null,estatus:'pendiente',observacionesAdmin:'',comentariosTrabajador:'',evidenciaFotos:[],historialEventos:[],evidenciasCount:0,cantidadEvidencias:0,ultimoAvance:null,requiereEvidencia:true,creadoPor:'master',creadoEn:serverTimestamp()});
test('master creates a task for a member of their project',async()=>{await assertSucceeds(setDoc(doc(env.authenticatedContext('master').firestore(),'actividades','good'),task()));});
test('master cannot create a task outside their project or assign an outsider',async()=>{
 const db=env.authenticatedContext('master').firestore();
 await assertFails(setDoc(doc(db,'actividades','outside-project'),task('other','outside')));
 await assertFails(setDoc(doc(db,'actividades','outside-user'),task('own','outside')));
});
test('workers and anonymous visitors cannot grant themselves master task creation',async()=>{
 await assertFails(setDoc(doc(env.authenticatedContext('worker').firestore(),'actividades','worker-task'),{...task(),creadoPor:'worker'}));
 await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(),'actividades','anon'),task()));
});
test('master cannot forge completion evidence, financial notes or project membership',async()=>{
 const db=env.authenticatedContext('master').firestore();
 await assertFails(setDoc(doc(db,'actividades','forged'),{...task(),estatus:'completado'}));
 await assertFails(setDoc(doc(db,'actividades','notes'),{...task(),observacionesAdmin:'altered'}));
 await assertFails(updateDoc(doc(db,'proyectos','own'),{encargados:['master','worker','outside']}));
});
test('project chat is private to assigned team and admin',async()=>{
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'proyectos','own','conversacion','message'),{autorId:'worker',texto:'Private evidence',fecha:Timestamp.now()}));
 await assertSucceeds(getDoc(doc(env.authenticatedContext('worker').firestore(),'proyectos','own','conversacion','message')));
 await assertFails(getDoc(doc(env.authenticatedContext('outside').firestore(),'proyectos','own','conversacion','message')));
});

test('personal notices can be queried by the recipient, not another worker',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'notificaciones','private'),{destinatarioId:'worker',rolesDestinatarios:[],leidosPor:[],mensaje:'Personal',creadoPor:'master'});
  await setDoc(doc(c.firestore(),'notificaciones','general'),{destinatarioId:'todos',rolesDestinatarios:['todos'],leidosPor:[],mensaje:'General',creadoPor:'admin'});
 });
 const db=env.authenticatedContext('worker').firestore();
 await assertSucceeds(getDocs(query(collection(db,'notificaciones'),or(where('destinatarioId','==','worker'),where('destinatarioId','==','todos'),where('rolesDestinatarios','array-contains-any',['trabajador','todos'])))));
 await assertFails(getDocs(collection(db,'notificaciones')));
 const other=env.authenticatedContext('outside').firestore();
 await assertFails(getDoc(doc(other,'notificaciones','private')));
 await assertFails(updateDoc(doc(other,'notificaciones','private'),{leidosPor:['outside']}));
 await assertSucceeds(getDoc(doc(other,'notificaciones','general')));
});
