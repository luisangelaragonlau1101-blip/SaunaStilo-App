const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,collection,query,where,setDoc,getDoc,getDocs,updateDoc,deleteDoc,runTransaction,writeBatch,serverTimestamp,Timestamp}=require('firebase/firestore');
let env;
const db=u=>env.authenticatedContext(u).firestore();
const request=(qty=2)=>({proyectoId:'p',proyectoNombre:'Prueba',trabajadorId:'worker',trabajadorNombre:'Prueba trabajador',insumoId:'hammer',nombreInsumo:'Martillo',cantidad:qty,esRetornable:true,estatus:'pendiente',marcadoDevueltoTrabajador:false,devueltoConfirmadoAdmin:false,tieneReporteFalla:false,fechaSolicitud:Timestamp.now(),fechaAprobacion:null,fechaLimiteDevolucion:null,observacionesDevolucion:null,fotoDevolucionUrl:null,fechaMarcadoDevuelto:null});
const task=u=>({proyectoId:'p',titulo:'Nueva actividad',descripcion:'Prueba aislada',asignadoATrabajadorId:'worker',fechaInicio:Timestamp.fromMillis(100000),fechaTermino:Timestamp.fromMillis(200000),fechaAsignada:Timestamp.fromMillis(100000),completadoEn:null,estatus:'pendiente',observacionesAdmin:'',comentariosTrabajador:'',evidenciaFotos:[],historialEventos:[],evidenciasCount:0,cantidadEvidencias:0,ultimoAvance:null,requiereEvidencia:true,creadoPor:u,creadoEn:serverTimestamp()});
test.before(async()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Isolated emulator required');env=await initializeTestEnvironment({projectId:'demo-sauna-ops',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});await env.withSecurityRulesDisabled(async c=>{
 for(const [id,rol]of [['admin','admin'],['warehouse','almacenista'],['master','maestro'],['worker','trabajador'],['other','trabajador']])await setDoc(doc(c.firestore(),'usuarios',id),{nombre:id,correo:id+'@example.invalid',rol,activo:true});
 await setDoc(doc(c.firestore(),'proyectos','p'),{titulo:'Prueba',encargados:['master','worker']});
 await setDoc(doc(c.firestore(),'proyectos','outside'),{titulo:'Ajeno',encargados:['other']});
 await setDoc(doc(c.firestore(),'actividades','unrelated'),{...task('other'),proyectoId:'outside',asignadoATrabajadorId:'other'});
 await setDoc(doc(c.firestore(),'insumos_inventario','hammer'),{cantidad_disponible:10,en_reparacion:0});
});});test.after(async()=>env?.cleanup());
test('admin and assigned master create tasks transactionally without notice permissions',async()=>{
 for(const user of ['admin','master']){const database=db(user),r=doc(database,'actividades','new-'+user);await assertSucceeds(runTransaction(database,async tx=>{const old=await tx.get(r);assert.equal(old.exists(),false);tx.set(r,task(user));}));await assertSucceeds(getDoc(r));}
 await assertFails(getDoc(doc(db('master'),'actividades','unrelated')));
 await assertFails(setDoc(doc(db('worker'),'actividades','forged'),task('worker')));
});
test('workers request but cannot self-approve, change another request or grant captures exemption',async()=>{
 const database=db('worker'),r=doc(database,'solicitudes_herramientas','request');await assertSucceeds(setDoc(r,request()));
 await assertFails(updateDoc(r,{estatus:'aprobada'}));
 await assertFails(updateDoc(doc(db('other'),'solicitudes_herramientas','request'),{cantidad:5}));
 await assertFails(updateDoc(doc(database,'usuarios','worker'),{bloquearCapturas:false}));
 await assertSucceeds(updateDoc(doc(db('admin'),'usuarios','worker'),{bloquearCapturas:true}));
});
async function move(id,action,{quantityOverride,actor='warehouse'}={}){
 const database=db(actor),r=doc(database,'solicitudes_herramientas',id),item=doc(database,'insumos_inventario','hammer');
 return runTransaction(database,async tx=>{const snapshot=await tx.get(r),stock=await tx.get(item),d=snapshot.data(),n=quantityOverride??d.cantidad;
  if(action==='salida'&&d.estatus==='aprobada'||action==='entrada'&&d.devueltoConfirmadoAdmin)return;
  const changed=action==='salida'?{estatus:'aprobada',fechaAprobacion:serverTimestamp(),autorizadoPorAdminId:actor,notaAdmin:''}:{devueltoConfirmadoAdmin:true,recibidoPor:actor,fechaRecepcion:serverTimestamp()};
  tx.update(r,changed);
  tx.update(item,action==='salida'?{cantidad_disponible:stock.data().cantidad_disponible-n}:d.tieneReporteFalla?{en_reparacion:stock.data().en_reparacion+n}:{cantidad_disponible:stock.data().cantidad_disponible+n});
  tx.set(doc(r,'historial',action),{accion:action,solicitudId:id,insumoId:'hammer',cantidad:d.cantidad,responsableId:actor,responsableNombre:actor,trabajadorId:'worker',fecha:serverTimestamp(),observacion:'',conFalla:action==='entrada'&&d.tieneReporteFalla});
 });
}
test('warehouse approves once, recipient reports return, warehouse confirms once with immutable audit',async()=>{
 await assertSucceeds(move('request','salida'));assert.equal((await getDoc(doc(db('warehouse'),'insumos_inventario','hammer'))).data().cantidad_disponible,8);
 await assertSucceeds(move('request','salida'));assert.equal((await getDoc(doc(db('warehouse'),'insumos_inventario','hammer'))).data().cantidad_disponible,8);
 await assertSucceeds(updateDoc(doc(db('worker'),'solicitudes_herramientas','request'),{marcadoDevueltoTrabajador:true,tieneReporteFalla:false,observacionesDevolucion:'Devuelvo en buen estado',fotoDevolucionUrl:'',fechaMarcadoDevuelto:serverTimestamp()}));
 await assertSucceeds(move('request','entrada'));await assertSucceeds(move('request','entrada'));
 assert.equal((await getDoc(doc(db('warehouse'),'insumos_inventario','hammer'))).data().cantidad_disponible,10);
 for(const actor of ['warehouse','admin']){await assertFails(deleteDoc(doc(db(actor),'solicitudes_herramientas','request')));await assertFails(updateDoc(doc(db(actor),'solicitudes_herramientas','request','historial','salida'),{cantidad:9}));}
 await assertSucceeds(getDocs(collection(db('worker'),'solicitudes_herramientas','request','historial')));
});
test('no stock means no approval, history or partial stock write',async()=>{
 await assertSucceeds(setDoc(doc(db('worker'),'solicitudes_herramientas','too-many'),request(50)));
 await assertFails(move('too-many','salida'));
 assert.equal((await getDoc(doc(db('warehouse'),'insumos_inventario','hammer'))).data().cantidad_disponible,10);
 assert.equal((await getDoc(doc(db('warehouse'),'solicitudes_herramientas','too-many'))).data().estatus,'pendiente');
});
test('worker cancellation preserves original request and cannot be approved later',async()=>{
 await assertSucceeds(setDoc(doc(db('worker'),'solicitudes_herramientas','cancel'),request()));
 await assertSucceeds(updateDoc(doc(db('worker'),'solicitudes_herramientas','cancel'),{estatus:'cancelada',canceladoPor:'worker',fechaCancelacion:serverTimestamp()}));
 await assertFails(move('cancel','salida'));
});
test('damaged returns enter repairs, never available stock',async()=>{
 await assertSucceeds(setDoc(doc(db('worker'),'solicitudes_herramientas','damaged'),request()));await assertSucceeds(move('damaged','salida'));
 await assertSucceeds(updateDoc(doc(db('worker'),'solicitudes_herramientas','damaged'),{marcadoDevueltoTrabajador:true,tieneReporteFalla:true,observacionesDevolucion:'Falla',fotoDevolucionUrl:'',fechaMarcadoDevuelto:serverTimestamp()}));
 await assertSucceeds(move('damaged','entrada'));
 const s=(await getDoc(doc(db('warehouse'),'insumos_inventario','hammer'))).data();assert.equal(s.cantidad_disponible,8);assert.equal(s.en_reparacion,2);
});
test('warehouse sees loans between coworkers without granting workers warehouse permissions',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'traspasos_inventario','t'),{participantes:['worker','master'],origen_usuario_id:'worker',destino_usuario_id:'master',estado:'pendiente'}));
 await assertSucceeds(getDocs(collection(db('warehouse'),'traspasos_inventario')));await assertFails(getDocs(collection(db('other'),'traspasos_inventario')));
});
test('two accounts invite, accept, take legal turns; outsiders, forged winners and multiple cells denied',async()=>{
 const id='juego_worker_example',a=db('worker'),b=db('master'),g=doc(a,'partidas_equipo',id);
 const data={jugadores:['worker','master'],nombres:['A','B'],tablero:Array(9).fill(''),estado:'invitada',turno:'worker',resultado:'',creadoPor:'worker',fecha:serverTimestamp(),actualizadaEn:serverTimestamp()};
 await assertSucceeds(runTransaction(a,async tx=>{assert.equal((await tx.get(g)).exists(),false);tx.set(g,data);}));
 await assertSucceeds(getDocs(query(collection(b,'partidas_equipo'),where('jugadores','array-contains','master'))));
 await assertFails(getDoc(doc(db('other'),'partidas_equipo',id)));await assertFails(getDoc(doc(db('admin'),'partidas_equipo',id)));
 await assertFails(updateDoc(g,{estado:'jugando',actualizadaEn:serverTimestamp()}));await assertSucceeds(updateDoc(doc(b,'partidas_equipo',id),{estado:'jugando',actualizadaEn:serverTimestamp()}));
 await assertSucceeds(updateDoc(g,{tablero:['X','','','','','','','',''],turno:'master',resultado:'',estado:'jugando',actualizadaEn:serverTimestamp()}));
 await assertFails(updateDoc(g,{tablero:['X','X','','','','','','',''],turno:'master',resultado:'',estado:'jugando',actualizadaEn:serverTimestamp()}));
 await assertFails(updateDoc(doc(b,'partidas_equipo',id),{tablero:['X','O','O','','','','','',''],turno:'worker',resultado:'',estado:'jugando',actualizadaEn:serverTimestamp()}));
 await assertFails(updateDoc(doc(b,'partidas_equipo',id),{tablero:['X','O','','','','','','',''],turno:'worker',resultado:'O',estado:'terminada',actualizadaEn:serverTimestamp()}));
 await assertSucceeds(updateDoc(doc(b,'partidas_equipo',id),{tablero:['X','O','','','','','','',''],turno:'worker',resultado:'',estado:'jugando',actualizadaEn:serverTimestamp()}));
});

test('complete legal games include the last cell, a win, a draw and reject play after completion',async()=>{
 const cases=[{id:'win',moves:[8,0,4,1,6,2],result:'O'},{id:'draw',moves:[0,1,2,4,3,5,7,6,8],result:'empate'}];
 for(const scenario of cases){
  const id='juego_worker_'+scenario.id,board=Array(9).fill('');
  await assertSucceeds(setDoc(doc(db('worker'),'partidas_equipo',id),{jugadores:['worker','master'],nombres:['A','B'],tablero:board,estado:'invitada',turno:'worker',resultado:'',creadoPor:'worker',fecha:serverTimestamp(),actualizadaEn:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db('master'),'partidas_equipo',id),{estado:'jugando',actualizadaEn:serverTimestamp()}));
  for(let n=0;n<scenario.moves.length;n++){
   const actor=n%2?'master':'worker',next=n%2?'worker':'master',finished=n===scenario.moves.length-1;
   board[scenario.moves[n]]=n%2?'O':'X';
   await assertSucceeds(updateDoc(doc(db(actor),'partidas_equipo',id),{tablero:[...board],turno:next,resultado:finished?scenario.result:'',estado:finished?'terminada':'jugando',actualizadaEn:serverTimestamp()}));
  }
  const saved=(await getDoc(doc(db('worker'),'partidas_equipo',id))).data();assert.equal(saved.resultado,scenario.result);
  await assertFails(updateDoc(doc(db(saved.turno),'partidas_equipo',id),{estado:'jugando',resultado:'',actualizadaEn:serverTimestamp()}));
 }
});
