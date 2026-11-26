const test=require('node:test'),assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const r=createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=r('firebase-admin/app'),{getFirestore}=r('firebase-admin/firestore');
const {runFinance}=require('../functions/enterprise-finance');
let app,db;
const invoke=(uid,action,operationId,fields={})=>runFinance({auth:{uid},data:{action,operationId,...fields}},{db});
test.before(async()=>{
 assert.ok(process.env.FIRESTORE_EMULATOR_HOST,'Isolated emulator required');
 app=initializeApp({projectId:'demo-sauna-finance-integration'});db=getFirestore(app);
 await db.collection('usuarios').doc('admin').set({rol:'admin',activo:true});
 await db.collection('usuarios').doc('buyer').set({rol:'trabajador',activo:true,permisosEmpresa:['solicitarCompras']});
 await db.collection('usuarios').doc('approver').set({rol:'trabajador',activo:true,permisosEmpresa:['autorizarCompras']});
 await db.collection('usuarios').doc('other').set({rol:'trabajador',activo:true});
});
test.after(async()=>deleteApp(app));
test('concurrent expense retries create one movement, invoice request and audit',async()=>{
 const fields={tipo:'egreso',centavos:345000,concepto:'Compra de herramientas',cuentaId:'caja',facturaOpcion:'necesito'};
 const result=await Promise.all([invoke('admin','recordMovement','expense_retry',fields),invoke('admin','recordMovement','expense_retry',fields)]);
 assert.equal(result[0].id,result[1].id);
 assert.equal((await db.collection('gestion_movimientos').get()).size,1);
 const invoices=await db.collection('gestion_facturas').get();assert.equal(invoices.size,1);assert.equal(invoices.docs[0].data().estado,'pendiente');
 assert.equal((await db.collection('gestion_auditoria').get()).size,1);
 await assert.rejects(invoke('admin','recordMovement','expense_retry',{...fields,centavos:1}));
});
test('purchase approval and conversion preserve identity and cannot duplicate the expense',async()=>{
 const request=await invoke('buyer','requestPurchase','purchase_request',{producto:'Cepilladora',motivo:'Fabricar duela',centavosEstimados:50000});
 assert.equal((await db.collection('notificaciones').where('destinatarioId','==','approver').get()).size,1);
 await assert.rejects(invoke('buyer','resolvePurchase','self_approval',{id:request.id,estado:'aprobada'}));
 assert.equal((await db.collection('gestion_compras').doc(request.id).get()).data().estado,'pendiente');
 await invoke('admin','resolvePurchase','admin_approval',{id:request.id,estado:'aprobada'});
 const fields={purchaseId:request.id,centavos:50000,cuentaId:'caja',facturaOpcion:'revisar'};
 const a=await invoke('buyer','convertPurchase','convert_once',fields);
 const b=await invoke('buyer','convertPurchase','convert_retry',fields);
 assert.equal(a.id,b.id);
 assert.equal((await db.collection('gestion_movimientos').where('compraId','==',request.id).get()).size,1);
});
test('staff without permission cannot read the financial dashboard or create income',async()=>{
 await assert.rejects(invoke('other','dashboard','forged_dashboard'));
 await assert.rejects(invoke('buyer','recordMovement','forged_income',{tipo:'ingreso',centavos:10000}));
 assert.equal((await db.collection('gestion_movimientos').where('tipo','==','ingreso').get()).size,0);
});


test('historical movements are explicitly classified without duplicating money and retain their previous classification in audit',async()=>{
 const original={tipo:'ingreso',concepto:'Anticipo anterior',centavos:116000,moneda:'MXN',fecha:new Date('2026-11-10T12:00:00Z'),creadoPor:'admin'};
 await db.collection('gestion_movimientos').doc('historic').set(original);
 await invoke('admin','classifyMovement','classify_history',{id:'historic',subtipo:'anticipo',cuentaId:'banco_principal',fiscal:{tratamiento:'gravado',tasaBps:1600,totalCentavos:116000}});
 const movement=(await db.collection('gestion_movimientos').doc('historic').get()).data();
 assert.equal(movement.centavos,original.centavos);assert.equal(movement.subtipo,'anticipo');assert.equal(movement.fiscal.ivaCentavos,16000);
 const audit=(await db.collection('gestion_auditoria').doc('admin_classify_history').get()).data();
 assert.equal(audit.anterior.subtipo,null);assert.equal(audit.solicitud.cuentaId,'banco_principal');
 await assert.rejects(invoke('admin','classifyMovement','invalid_class',{id:'historic',subtipo:'compra',fiscal:{tratamiento:'gravado',totalCentavos:116000}}));
 assert.equal((await db.collection('gestion_movimientos').doc('historic').get()).data().subtipo,'anticipo');
});
