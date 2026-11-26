const test=require('node:test'),assert=require('node:assert/strict');
const f=require('../functions/enterprise-finance-domain');
const i=require('../functions/enterprise-installations');
test('own account transfers preserve total funds without generating sales',()=>{
 const rows=[{tipo:'traspaso',cuentaOrigenId:'bank',cuentaDestinoId:'cash',centavos:2500}];
 const accounts=f.accountBalances(rows,[{id:'bank',saldoInicialCentavos:10000},{id:'cash',saldoInicialCentavos:1000}]);
 assert.deepEqual(accounts.map(a=>a.saldoRegistrado),[7500,3500]);
 const summary=f.financialSummary(rows);assert.equal(summary.ingresos,0);assert.equal(summary.ventasCobradas,0);
});
test('partial payment allocates VAT only to actual cash collected',()=>{
 const fiscal=f.fiscalData({tratamiento:'gravado',totalCentavos:11600,tasaBps:1600},5800);
 assert.equal(fiscal.pendienteCentavos,5800);
 const tax=f.effectiveTax({centavos:5800,fiscal});assert.equal(tax.base,5000);assert.equal(tax.vat,800);
});
test('unverified receipt gives no VAT credit and owner deposits give no sales',()=>{
 const fiscal=f.fiscalData({tratamiento:'gravado',totalCentavos:11600},11600);
 const summary=f.financialSummary([{tipo:'egreso',centavos:11600,fiscal,facturaEstado:'pendiente'},{tipo:'ingreso',subtipo:'aportacion',centavos:20000}]);
 assert.equal(summary.ivaAcreditable,0);assert.equal(summary.ventasCobradas,0);assert.equal(summary.isrEstimado,null);
});
test('only verified, explicitly confirmed paid purchases grant VAT credit',()=>{
 const fiscal={...f.fiscalData({tratamiento:'gravado',totalCentavos:11600},5800),acreditableConfirmado:true};
 assert.equal(f.financialSummary([{tipo:'egreso',centavos:5800,fiscal,facturaEstado:'verificada'}]).ivaAcreditable,800);
});
test('client advances are not project profit and unknown selling price remains unknown',()=>{
 const p=f.projectProfitability({id:'project'},[{tipo:'ingreso',subtipo:'anticipo',proyectoId:'project',centavos:10000}]);
 assert.equal(p.anticiposCentavos,10000);assert.equal(p.margenEstimado,null);
});
test('CFDI parser rejects external entities and photos masquerading as XML',()=>{
 for(const xml of ['<!DOCTYPE a [<!ENTITY x SYSTEM "file:///etc/passwd">]><a>&x;</a>','data:image/jpeg;base64,abcdef','<not-cfdi/>'])assert.throws(()=>f.parseCfdi(xml));
});
test('installation preparation rejects duplicate, fractional and negative quantities',()=>{
 const line={sourceId:'drill',sourceType:'inventario',cantidad:2};
 assert.throws(()=>i.normalizeLines([line,line]));
 for(const cantidad of [-1,1.5,0])assert.throws(()=>i.normalizeLines([{...line,cantidad}]));
});
test('return quantities cannot exceed departure or consume a returnable tool',()=>{
 const order={salida:{lineas:[{id:'drill',tipo:'retornable',entregada:2}]}};
 const row={id:'drill',devuelta:1,danada:0,utilizada:0,desperdicio:0,instalada:0};
 assert.equal(i.returnLines(order,[row])[0].faltante,1);
 assert.throws(()=>i.returnLines(order,[{...row,devuelta:3}]));
 assert.throws(()=>i.returnLines(order,[{...row,utilizada:1}]));
 assert.throws(()=>i.returnLines(order,[]));
});
test('short and out-of-range digital signatures are rejected',()=>{
 assert.throws(()=>i.signature([[[0.1,0.2]]]));
 assert.throws(()=>i.signature([[[0,0],[1,1],[2,1],[0,0],[0,0]]]));
 assert.equal(i.signature([[[0,0],[0.1,0.1],[0.2,0.3],[0.5,0.6],[1,1]]])[0].puntos.length,5);
});

test('unknown or pending fiscal regimes never expose an ISR estimate',()=>{
 for(const regimen of ['pendiente','desconocido',''])assert.equal(f.financialSummary([],{confirmada:true,regimen,isrMetodo:'estimacion_contabilidad',isrEstimados:{'2026-11':10000}},'2026-11').isrEstimado,null);
});

test('purchase notifications honor current approval permissions and preferences',()=>{
 const {shouldDeliverNotification}=require('../functions/enterprise-notification-policy');
 const note={tipo:'compra_pendiente',privadoCompras:true};
 assert.equal(shouldDeliverNotification({rol:'trabajador',activo:true},note),false);
 const approver={rol:'trabajador',activo:true,permisosEmpresa:['autorizarCompras']};
 assert.equal(shouldDeliverNotification(approver,note),true);
 assert.equal(shouldDeliverNotification(approver,note,{compras:false}),false);
});


test('project cost subtracts the eligible VAT credit rather than also deducting retained VAT',()=>{
 const fiscal={...f.fiscalData({tratamiento:'gravado',totalCentavos:11000,retencionIvaCentavos:600},11000),acreditableConfirmado:true};
 const movement={tipo:'egreso',centavos:11000,proyectoId:'project',facturaEstado:'verificada',fiscal};
 assert.equal(f.financialSummary([movement]).ivaAcreditable,1000);
 assert.equal(f.projectProfitability({id:'project'},[movement]).costoRegistrado,10000);
});
