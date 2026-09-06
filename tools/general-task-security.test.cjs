const test = require('node:test');
const fs = require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,serverTimestamp,Timestamp,runTransaction} = require('firebase/firestore');
let env;
test.before(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Only isolated emulator tests are allowed.');
 env=await initializeTestEnvironment({projectId:'demo-sauna-general-tasks',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{for(const [id,rol] of [['admin','admin'],['master','maestro'],['worker','trabajador'],['other','trabajador']])await setDoc(doc(c.firestore(),'usuarios',id),{nombre:id,correo:id+'@example.invalid',rol});});
});
test.after(async()=>{if(env)await env.cleanup();});
const data=()=>({proyectoId:'',titulo:'Preparar taller',descripcion:'Organizar herramientas',asignadoATrabajadorId:'worker',fechaInicio:Timestamp.now(),fechaAsignada:Timestamp.now(),fechaTermino:Timestamp.fromMillis(Date.now()+86400000),estatus:'pendiente',requiereEvidencia:true,creadoPor:'admin',creadoEn:serverTimestamp(),evidenciaFotos:[],historialEventos:[],evidenciasCount:0,cantidadEvidencias:0,completadoEn:null,ultimoAvance:null,observacionesAdmin:'',comentariosTrabajador:''});
test('admin assigns without a project, responsible worker sees it but unrelated accounts cannot',async()=>{
 const db=env.authenticatedContext('admin').firestore();const ref=doc(db,'actividades','general-one');
 await assertSucceeds(runTransaction(db,async tx=>{const p=await tx.get(doc(db,'usuarios','worker'));const old=await tx.get(ref);if(p.exists()&&!old.exists())tx.set(ref,data());}));
 const worker=env.authenticatedContext('worker').firestore();
 await assertSucceeds(getDoc(doc(worker,'actividades','general-one')));
 await assertSucceeds(updateDoc(doc(worker,'actividades','general-one'),{estatus:'en_progreso'}));
 await assertSucceeds(setDoc(doc(worker,'actividades','general-one','avances','first'),{usuarioId:'worker',comentario:'Comenzando'}));
 await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'actividades','general-one')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'actividades','general-one')));
});
test('master cannot use blank project to assign to an unrestricted employee',async()=>{
 await assertFails(setDoc(doc(env.authenticatedContext('master').firestore(),'actividades','general-forged'),{...data(),creadoPor:'master'}));
 await assertFails(setDoc(doc(env.authenticatedContext('worker').firestore(),'actividades','general-self'),{...data(),creadoPor:'worker'}));
});
