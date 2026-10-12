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
test('project selection lists only assigned projects and keeps global and foreign queries private',async()=>{
 for(const actor of ['master','worker','other']){
  const own=await assertSucceeds(getDocs(query(collection(db(actor),'proyectos'),where('encargados','array-contains',actor))));
  assert.deepEqual(own.docs.map(d=>d.id),actor==='other'?['outside']:['p']);
  await assertFails(getDocs(collection(db(actor),'proyectos')));
 }
 const admin=await assertSucceeds(getDocs(collection(db('admin'),'proyectos')));
 assert.deepEqual(admin.docs.map(d=>d.id).sort(),['outside','p']);
 await assertFails(getDocs(query(collection(db('other'),'proyectos'),where('encargados','array-contains','master'))));
 await assertFails(getDoc(doc(db('master'),'proyectos','outside')));
 await assertFails(getDocs(query(collection(env.unauthenticatedContext().firestore(),'proyectos'),where('encargados','array-contains','master'))));
});
test('master selects their project and team then assigns transactionally without granting outsider or general-task access',async()=>{
 const database=db('master');
 const projects=await assertSucceeds(getDocs(query(collection(database,'proyectos'),where('encargados','array-contains','master'))));
 const selected=projects.docs.find(d=>d.id==='p');assert.ok(selected);
 const people=await assertSucceeds(getDocs(collection(database,'usuarios')));
 const members=people.docs.filter(d=>d.data().activo!==false&&selected.data().encargados.includes(d.id)).map(d=>d.id).sort();
 assert.deepEqual(members,['master','worker']);
 const assign=(id,projectId,target)=>runTransaction(database,async tx=>{
  const profile=await tx.get(doc(database,'usuarios','master'));
  const assignee=await tx.get(doc(database,'usuarios',target));
  const project=projectId?await tx.get(doc(database,'proyectos',projectId)):null;
  const ref=doc(database,'actividades',id);const old=await tx.get(ref);
  assert.equal(profile.data().rol,'maestro');assert.equal(assignee.data().activo,true);
  if(projectId)assert.equal(project.exists(),true);
  assert.equal(old.exists(),false);
  tx.set(ref,{...task('master'),proyectoId:projectId,asignadoATrabajadorId:target});
 });
 await assertSucceeds(assign('selected-master-task',selected.id,'worker'));
 const saved=await assertSucceeds(getDoc(doc(db('worker'),'actividades','selected-master-task')));
 assert.equal(saved.data().creadoPor,'master');assert.equal(saved.data().proyectoId,'p');
 await assertFails(assign('selected-forged-member','p','other'));
 await assertFails(assign('selected-foreign-project','outside','other'));
 await assertFails(assign('selected-blank-project','','worker'));
 for(const id of ['selected-forged-member','selected-foreign-project','selected-blank-project'])assert.equal((await getDoc(doc(db('admin'),'actividades',id))).exists(),false);
 await assertFails(updateDoc(doc(database,'proyectos','p'),{encargados:['master','worker','other']}));
});
test('project list membership cannot be forged through malformed map or string fields',async()=>{
 const admin=db('admin'),master=db('master');
 const map=doc(admin,'proyectos','malformed-map'),string=doc(admin,'proyectos','malformed-string');
 try {
  await setDoc(map,{titulo:'Formato inválido',encargados:{master:true}});
  await setDoc(string,{titulo:'Formato histórico inválido',encargados:'master'});
  for(const id of ['malformed-map','malformed-string'])await assertFails(getDoc(doc(master,'proyectos',id)));
  await assertFails(getDocs(query(collection(master,'proyectos'),where('encargados.master','==',true))));
  await assertFails(getDocs(query(collection(master,'proyectos'),where('encargados','==',{master:true}))));
  await assertFails(getDocs(query(collection(master,'proyectos'),where('encargados','==','master'))));
  await assertSucceeds(getDoc(map));await assertSucceeds(getDoc(string));
 } finally {await deleteDoc(map);await deleteDoc(string);}
});
test('admin and assigned master create tasks transactionally without notice permissions',async()=>{
 for(const user of ['admin','master']){const database=db(user),r=doc(database,'actividades','new-'+user);await assertSucceeds(runTransaction(database,async tx=>{const old=await tx.get(r);assert.equal(old.exists(),false);tx.set(r,task(user));}));await assertSucceeds(getDoc(r));}
 await assertFails(getDoc(doc(db('master'),'actividades','unrelated')));
 await assertFails(setDoc(doc(db('worker'),'actividades','forged'),task('worker')));
});
test('administration reads the entire task registry with progress and evidence while staff retain assigned access',async()=>{
 const admin=db('admin');
 await assertSucceeds(setDoc(doc(admin,'actividades','overview-project'),task('admin')));
 await assertSucceeds(setDoc(doc(admin,'actividades','overview-extra'),{...task('admin'),proyectoId:'',workKind:'extra'}));
 const progress=doc(admin,'actividades','overview-project','avances','legacy-progress');
 const proof=doc(admin,'actividades','overview-project','evidencias','overview-photo');
 await assertSucceeds(setDoc(progress,{trabajadorId:'worker',comentario:'Avance real',porcentaje:65,fecha:serverTimestamp(),esCierre:false,cantidadEvidencias:1}));
 await assertSucceeds(setDoc(proof,{usuarioId:'worker',url:'data:image/png;base64,iVBORw0KGgo=',nombre:'avance.png',tipoMime:'image/png',creadoEn:serverTimestamp()}));
 const registry=await assertSucceeds(getDocs(collection(admin,'actividades')));
 for(const id of ['unrelated','overview-project','overview-extra'])assert.ok(registry.docs.some(d=>d.id===id));
 const events=await assertSucceeds(getDocs(collection(admin,'actividades','overview-project','avances')));
 assert.equal(events.docs.find(d=>d.id==='legacy-progress').data().porcentaje,65);
 const files=await assertSucceeds(getDocs(collection(admin,'actividades','overview-project','evidencias')));
 assert.equal(files.docs.find(d=>d.id==='overview-photo').data().nombre,'avance.png');
 for(const actor of ['worker','master','warehouse','other'])await assertFails(getDocs(collection(db(actor),'actividades')));
 await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'actividades')));
 const own=await assertSucceeds(getDocs(query(collection(db('worker'),'actividades'),where('asignadoATrabajadorId','==','worker'))));
 assert.ok(own.docs.some(d=>d.id==='overview-project'));assert.ok(!own.docs.some(d=>d.id==='unrelated'));
 await assertSucceeds(getDocs(query(collection(db('master'),'actividades'),where('proyectoId','==','p'))));
 await assertSucceeds(getDocs(collection(db('worker'),'actividades','overview-project','avances')));
 await assertSucceeds(getDocs(collection(db('worker'),'actividades','overview-project','evidencias')));
 await assertFails(getDocs(collection(db('other'),'actividades','overview-project','avances')));
 await assertFails(getDocs(collection(db('other'),'actividades','overview-project','evidencias')));
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

 test('product photo is saved with the product using existing warehouse authorization', async()=>{
  const photo='data:image/png;base64,iVBORw0KGgo=';
  const product=doc(db('warehouse'),'insumos_inventario','photo-product');
  await assertSucceeds(setDoc(product,{nombre:'Prueba de foto',imagen_url:photo,cantidad_disponible:1}));
  assert.equal((await assertSucceeds(getDoc(doc(db('worker'),'insumos_inventario','photo-product')))).data().imagen_url,photo);
  await assertFails(updateDoc(doc(db('worker'),'insumos_inventario','photo-product'),{imagen_url:'forged'}));
 });

test('private HR files and internal finance records remain admin-only under existing rules',async()=>{
 const admin=db('admin');
 for(const [path,data] of [['rh_expedientes/worker',{puesto:'Prueba QA',notas:'Expediente aislado'}],['gestion_movimientos/test',{tipo:'ingreso',centavos:100,moneda:'MXN'}]]) {
  await assertSucceeds(setDoc(doc(admin,path),data)); await assertSucceeds(getDoc(doc(admin,path)));
  for(const role of ['worker','master','warehouse','other']) {
   await assertFails(getDoc(doc(db(role),path))); await assertFails(setDoc(doc(db(role),path),data));
  }
 }
});
test('assigned worker persists a bounded photo with description and closes a task without Storage',async()=>{
 const database=db('worker');
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'actividades','inline-evidence'),task('admin')));
 const batch=writeBatch(database);
 batch.set(doc(database,'actividades','inline-evidence','evidencias','photo'),{url:'data:image/png;base64,iVBORw0KGgo=',usuarioId:'worker',nombre:'foto.png',tipoMime:'image/png',creadoEn:serverTimestamp()});
 batch.update(doc(database,'actividades','inline-evidence'),{estatus:'en_revision',comentariosTrabajador:'Actividad terminada con evidencia',evidenciasCount:1,cantidadEvidencias:1,completadoEn:serverTimestamp()});
 await assertSucceeds(batch.commit());
 const proof=await assertSucceeds(getDoc(doc(db('admin'),'actividades','inline-evidence','evidencias','photo')));assert.match(proof.data().url,/^data:image\/png/);
 await assertFails(getDoc(doc(db('other'),'actividades','inline-evidence','evidencias','photo')));
});

test('project delivery uses the authorized group; only admin can atomically finalize with its audit message',async()=>{
 const worker=db('worker'),admin=db('admin'),other=db('other');
 const request={autorId:'worker',autorNombre:'worker',tipo:'entrega_proyecto',texto:'Proyecto terminado, por aprobar',fecha:serverTimestamp(),imagenes:[],likesPor:[]};
 const delivery=doc(worker,'proyectos','p','conversacion','project-delivery');
 await assertFails(runTransaction(worker,async tx=>{
  await tx.get(doc(worker,'proyectos','p'));
  tx.set(delivery,request);tx.update(doc(worker,'proyectos','p'),{estatus:'finalizado',aprobadoPor:'worker'});
 }));
 assert.equal((await getDoc(delivery)).exists(),false,'A rejected self-approval cannot leave a delivery behind');
 await assertSucceeds(runTransaction(worker,async tx=>{await tx.get(doc(worker,'proyectos','p'));tx.set(delivery,request);}));
 await assertFails(setDoc(doc(other,'proyectos','p','conversacion','outside-delivery'),{...request,autorId:'other'}));
 await assertFails(updateDoc(doc(worker,'proyectos','p'),{estatus:'finalizado',aprobadoPor:'worker'}));
 await assertSucceeds(runTransaction(admin,async tx=>{
  await tx.get(doc(admin,'proyectos','p'));
  tx.update(doc(admin,'proyectos','p'),{estatus:'finalizado',aprobadoEn:serverTimestamp(),aprobadoPor:'admin',revisionProyectoEn:serverTimestamp()});
  tx.set(doc(admin,'proyectos','p','conversacion','project-approval'),{...request,autorId:'admin',tipo:'aprobacion_proyecto',texto:'Aprobado y finalizado'});
 }));
 assert.equal((await getDoc(doc(worker,'proyectos','p'))).data().estatus,'finalizado');
 await assertSucceeds(getDoc(doc(worker,'proyectos','p','conversacion','project-approval')));
});

test('admin can deliver a task assigned to a worker while unrelated staff cannot',async()=>{
 const admin=db('admin'),ref=doc(admin,'actividades','admin-delivery');
 await setDoc(ref,task('admin'));
 await assertSucceeds(runTransaction(admin,async tx=>{
  await tx.get(ref);
  tx.set(doc(admin,'actividades','admin-delivery','avances','admin-event'),{trabajadorId:'admin',comentario:'Trabajo confirmado por Administración',esCierre:true,fecha:serverTimestamp(),porcentaje:100,cantidadEvidencias:0});
  tx.update(ref,{estatus:'en_revision',completadoEn:serverTimestamp(),porcentaje:100});
 }));
 await assertFails(updateDoc(doc(db('other'),'actividades','admin-delivery'),{estatus:'en_revision',completadoEn:serverTimestamp()}));
 await assertSucceeds(updateDoc(ref,{estatus:'completado',aprobadoEn:serverTimestamp(),porcentaje:100}));
});
