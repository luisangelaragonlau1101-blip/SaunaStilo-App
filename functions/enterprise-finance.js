'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const access = require('./enterprise-access');
const domain = require('./enterprise-finance-domain');

const DEFAULT_ACCOUNTS = [
  { id: 'banco_principal', nombre: 'Cuenta bancaria empresarial', tipo: 'banco', principal: true, saldoInicialCentavos: 0 },
  { id: 'caja', nombre: 'Caja de efectivo', tipo: 'efectivo', principal: false, saldoInicialCentavos: 0 },
];
const fail = message => { throw new HttpsError('failed-precondition', message); };
const text = (v, max = 200) => String(v ?? '').trim().slice(0, max);
function id(v) { const s = text(v, 150); if (!/^[A-Za-z0-9_-]{1,150}$/.test(s)) fail('La referencia no es válida.'); return s; }
function date(v) { const d = new Date(v); if (!Number.isFinite(d.getTime()) || d.getUTCFullYear() < 2000 || d.getUTCFullYear() > 2100) fail('Revisa la fecha.'); return d; }
function serialize(v) {
  if (v && typeof v.toDate === 'function') return v.toDate().toISOString();
  if (Array.isArray(v)) return v.map(serialize);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, value]) => [k, serialize(value)]));
  return v;
}
const documents = snap => snap.docs.map(d => ({ ...serialize(d.data()), id: d.id }));
const canView = p => access.canFinance(p) || access.hasPermission(p, 'direccion');
const canSpend = p => access.canFinance(p) || access.canRequestPurchase(p);
function requirePermission(ok) { if (!ok) throw new HttpsError('permission-denied', 'Tu cuenta no tiene permiso para esta operación.'); }
function fileRefs(value, uid) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 8) fail('Puedes adjuntar hasta ocho archivos por registro.');
  return value.map(f => {
    const path = text(f.path, 500), name = text(f.name, 160), mime = text(f.contentType, 100);
    if (!path.startsWith(`finance/${uid}/`) || path.includes('..') || !name || !['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/xml', 'text/xml'].includes(mime)) fail('El comprobante no pertenece a esta sesión o su formato no es válido.');
    return { path, name, contentType: mime, subidoPor: uid };
  });
}
function safeMovement(data, uid) {
  const amount = domain.cents(data.centavos);
  const kind = data.tipo || 'egreso';
  if (!['ingreso', 'egreso'].includes(kind)) fail('Selecciona ingreso o gasto.');
  const subtype = text(data.subtipo || (kind === 'egreso' ? 'compra' : 'otro'), 40);
  const allowed = kind === 'ingreso' ? ['venta', 'anticipo', 'parcialidad', 'liquidacion', 'aportacion', 'devolucion', 'otro', 'deposito'] : ['compra', 'retiro', 'impuesto', 'devolucion', 'otro'];
  if (!allowed.includes(subtype)) fail('El tipo de movimiento no corresponde.');
  const invoiceChoice = ['necesito', 'tengo', 'revisar'].includes(data.facturaOpcion) ? data.facturaOpcion : 'revisar';
  return {
    schemaVersion: 2026, tipo: kind, subtipo: subtype, centavos: amount, moneda: 'MXN', concepto: text(data.concepto || (kind === 'egreso' ? 'Compra por clasificar' : 'Cobro por clasificar'), 160),
    categoria: text(data.categoria || 'Por clasificar', 80), cuentaId: id(data.cuentaId || 'banco_principal'), medioPago: text(data.medioPago || 'por_clasificar', 40), fecha: Timestamp.fromDate(date(data.fecha || new Date().toISOString())),
    cliente: text(data.cliente), proveedor: text(data.proveedor), proyectoId: data.proyectoId ? id(data.proyectoId) : '', referencia: text(data.referencia), observaciones: text(data.observaciones, 2000),
    naturaleza: data.naturaleza === 'inversion' ? 'inversion' : 'operacion', fiscal: domain.fiscalData(data.fiscal, amount), facturaOpcion: invoiceChoice, facturaEstado: invoiceChoice === 'necesito' ? 'pendiente' : invoiceChoice === 'tengo' ? 'verificacion_pendiente' : 'no_facturable',
    archivos: fileRefs(data.archivos, uid), creadoPor: uid, creadoEn: FieldValue.serverTimestamp(),
  };
}
async function dashboard(db, profile, uid, data) {
  requirePermission(canView(profile));
  const month = /^\d{4}-\d{2}$/.test(data.month || '') ? data.month : new Date().toISOString().slice(0, 7);
  const [ledger, accountSn, invoiceSn, requestSn, budgetSn, configSn, projectSn, plansSn, statementSn] = await Promise.all([
    db.collection('gestion_movimientos').get(), db.collection('gestion_cuentas').get(), db.collection('gestion_facturas').get(), db.collection('gestion_compras').get(), db.collection('gestion_presupuestos').get(), db.collection('gestion_config').doc('fiscal').get(), db.collection('proyectos').get(), db.collection('gestion_proyectos').get(), db.collection('gestion_conciliaciones').where('mes', '==', month).get(),
  ]);
  const all = documents(ledger), invoiceMap = new Map(documents(invoiceSn).map(f => [f.movimientoId, f]));
  for (const m of all) if (invoiceMap.has(m.id)) m.facturaEstado = invoiceMap.get(m.id).estado;
  const rows = all.filter(m => typeof m.fecha === 'string' && m.fecha.slice(0, 7) === month).sort((a, b) => b.fecha.localeCompare(a.fecha));
  const configured = documents(accountSn), accounts = domain.accountBalances(all, [...DEFAULT_ACCOUNTS.filter(a => !configured.some(c => c.id === a.id)), ...configured]);
  const config = configSn.exists ? serialize(configSn.data()) : {};
  const budgets = documents(budgetSn).map(b => ({ ...b, gastadoCentavos: all.filter(m => m.tipo === 'egreso' && (!b.proyectoId || m.proyectoId === b.proyectoId) && (!b.categoria || m.categoria === b.categoria) && (!b.mes || m.fecha?.slice(0, 7) === b.mes)).reduce((s, m) => s + m.centavos, 0) }));
  const reserve = ['reservaFiscalCentavos', 'reservaMaterialesCentavos', 'reservaInstalacionesCentavos', 'reservaCompromisosCentavos'].reduce((s, k) => s + (config[k] || 0), 0);
  const projects = documents(projectSn).map(p => ({ id: p.id, titulo: p.titulo || p.nombre || 'Proyecto' }));
  return { month, viewerId: uid, movements: rows, accounts, invoices: documents(invoiceSn).filter(f => f.estado !== 'verificada'), requests: documents(requestSn), budgets, config,
    summary: { ...domain.financialSummary(rows, config, month), saldoRegistrado: accounts.reduce((s, a) => s + a.saldoRegistrado, 0), reservasCentavos: reserve, disponibleRegistrado: accounts.filter(a => ['banco','efectivo'].includes(a.tipo)).reduce((s, a) => s + a.saldoRegistrado, 0) - reserve, saldoSinCuenta: accounts.filter(a => !['banco','efectivo'].includes(a.tipo)).reduce((s, a) => s + a.saldoRegistrado, 0) },
    projects, statements: documents(statementSn), profitability: projects.map(p => domain.projectProfitability(p, all, documents(plansSn).find(x => x.id === p.id) || {})), canWrite: access.canFinance(profile), canApprove: access.canApprovePurchases(profile),
  };
}
async function mutate(db, uid, input, handler) {
  const operation = id(input.operationId), opRef = db.collection('gestion_operaciones').doc(`${uid}_${operation}`), digest = domain.hash(input);
  return db.runTransaction(async tx => {
    const [actor, existing] = await Promise.all([tx.get(db.collection('usuarios').doc(uid)), tx.get(opRef)]);
    const p = actor.exists ? actor.data() : null;
    requirePermission(access.active(p));
    if (existing.exists) { if (existing.data().digest !== digest) fail('El identificador ya corresponde a otra operación. Revisa el registro antes de continuar.'); return existing.data().result; }
    const audit = {};
    const result = await handler(tx, p, operation, audit);
    tx.create(opRef, { creadoPor: uid, accion: input.action, digest, result, creadoEn: FieldValue.serverTimestamp() });
    tx.create(db.collection('gestion_auditoria').doc(`${uid}_${operation}`), { creadoPor: uid, accion: input.action, operationId: operation, referencia: result.id || '', creadoEn: FieldValue.serverTimestamp(), digest, solicitud: input, ...audit });
    return result;
  });
}
function writeNotice(tx, db, uid, operation, { recipient, title, message, type, reference }, permissionRecipients=[]) {
  const roles=['admin','finanzas','contabilidad'];
  const body={titulo:title,mensaje:message,tipo:type,destinatarioId:recipient||'',rolesDestinatarios:recipient?[]:roles,privadoFinanzas:type.startsWith('factura'),privadoCompras:type==='compra_pendiente',leidosPor:[],creadoPor:uid,fecha:FieldValue.serverTimestamp(),entidadId:reference,pantalla:type.startsWith('compra')?'compras':'facturas'};
  tx.set(db.collection('notificaciones').doc(`finance_${uid}_${operation}`),body);
  if(!recipient)for(const profile of permissionRecipients){
    if(roles.includes(profile.rol))continue;
    const allowed=type.startsWith('compra')?access.canApprovePurchases(profile):access.canViewFinance(profile);
    if(allowed)tx.set(db.collection('notificaciones').doc(`finance_${uid}_${operation}_${profile.id}`),{...body,destinatarioId:profile.id,rolesDestinatarios:[]});
  }
}
async function runFinance(request, dependencies = {}) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  const db = dependencies.db || getFirestore(), data = request.data || {};
  const actor = await db.collection('usuarios').doc(uid).get(), profile = actor.exists ? actor.data() : null;
  requirePermission(access.active(profile));
  if (data.action === 'homeSummary') {
    requirePermission(canView(profile) || access.canApprovePurchases(profile));
    const financial = canView(profile), approve = access.canApprovePurchases(profile);
    const [invoices, purchases] = await Promise.all([
      financial ? db.collection('gestion_facturas').where('estado', 'in', ['pendiente', 'solicitada', 'esperando_proveedor', 'recibida', 'verificacion_pendiente', 'requiere_correccion']).count().get() : null,
      approve ? db.collection('gestion_compras').where('estado', 'in', ['pendiente', 'informacion_solicitada']).count().get() : null,
    ]);
    return { viewerId: uid, financial, canApprove: approve, facturasPendientes: invoices?.data().count ?? null, comprasPendientes: purchases?.data().count ?? null };
  }
  if (data.action === 'dashboard') return dashboard(db, profile, uid, data);
  if (data.action === 'myPurchases') {
    requirePermission(canSpend(profile));
    const [requests, expenses, projects] = await Promise.all([db.collection('gestion_compras').where('creadoPor', '==', uid).get(), db.collection('gestion_movimientos').where('creadoPor', '==', uid).get(), canView(profile) ? db.collection('proyectos').get() : db.collection('proyectos').where('encargados', 'array-contains', uid).get()]);
    return { requests: documents(requests), expenses: documents(expenses).filter(m => m.tipo === 'egreso'), projects: documents(projects).map(p => ({ id: p.id, titulo: p.titulo || p.nombre || 'Proyecto' })), canApprove: access.canApprovePurchases(profile), canWrite: canSpend(profile) };
  }
  if (data.action === 'getInvoice') {
    requirePermission(canView(profile));
    const invoice = await db.collection('gestion_facturas').doc(id(data.id)).get();
    if (!invoice.exists) fail('La solicitud ya no está disponible.');
    return { invoice: { ...serialize(invoice.data()), id: invoice.id } };
  }
  let parsed;
  if (data.action === 'invoiceAttach' && data.xmlPath) {
    requirePermission(access.canFinance(profile));
    const path = text(data.xmlPath, 500);
    if (!path.startsWith(`finance/${uid}/`) || path.includes('..') || !path.toLowerCase().endsWith('.xml')) fail('Selecciona el XML que acabas de adjuntar.');
    const bucket = dependencies.bucket || getStorage().bucket();
    const file = bucket.file(path), [metadata] = await file.getMetadata();
    if (Number(metadata.size) > 2 * 1024 * 1024) fail('El XML puede pesar hasta 2 MB.');
    const [bytes] = await file.download();
    parsed = domain.parseCfdi(bytes.toString('utf8'));
  }
  const notifying=['recordMovement','convertPurchase','requestPurchase','resolvePurchase','purchaseInformation','invoiceAttach','invoiceState','verifyInvoice'].includes(data.action);
  const recipients=notifying?documents(await db.collection('usuarios').where('permisosEmpresa','array-contains-any',['finanzas','autorizarCompras','direccion']).get()):[];
  const notify=(...args)=>writeNotice(...args,recipients);
  return mutate(db, uid, data, async (tx, p, operation, audit) => {
    const finance = access.canFinance(p);
    switch (data.action) {
      case 'recordMovement':
      case 'convertPurchase': {
        requirePermission(canSpend(p));
        let purchase, purchaseRef;
        if (data.action === 'convertPurchase') {
          purchaseRef = db.collection('gestion_compras').doc(id(data.purchaseId)); purchase = await tx.get(purchaseRef);
          if (!purchase.exists || purchase.data().estado !== 'aprobada') fail('Primero debe aprobarse la solicitud.');
          requirePermission(finance || purchase.data().creadoPor === uid);
          if (purchase.data().movimientoId) return { id: purchase.data().movimientoId, alreadyRecorded: true };
        }
        const values = { ...(purchase?.data() || {}), ...data, ...(purchase ? { tipo: 'egreso', concepto: data.concepto || purchase.data().producto, proyectoId: purchase.data().proyectoId || '', proveedor: data.proveedor || purchase.data().proveedor } : {}) };
        const movement = safeMovement(values, uid);
        requirePermission(finance || movement.tipo === 'egreso');
        if (!finance) { movement.fiscal = domain.fiscalData({}, movement.centavos); movement.naturaleza = 'operacion'; }
        const ref = db.collection('gestion_movimientos').doc(purchase ? `compra_${purchase.id}` : `empresa_${uid}_${operation}`);
        const [old, account, project] = await Promise.all([tx.get(ref), tx.get(db.collection('gestion_cuentas').doc(movement.cuentaId)), movement.proyectoId ? tx.get(db.collection('proyectos').doc(movement.proyectoId)) : Promise.resolve(null)]);
        if (old.exists) fail('Esta compra ya se registró.');
        if (!account.exists && !DEFAULT_ACCOUNTS.some(a => a.id === movement.cuentaId)) fail('La cuenta seleccionada no existe.');
        if (project && (!project.exists || (!finance && !project.data().encargados?.includes(uid)))) fail('El proyecto no está asignado a tu cuenta.');
        movement.operationId = operation;
        if (purchase) movement.compraId = purchase.id;
        tx.create(ref, movement);
        if (purchaseRef) tx.update(purchaseRef, { movimientoId: ref.id, convertidoPor: uid, convertidoEn: FieldValue.serverTimestamp() });
        if (movement.tipo === 'egreso' && movement.facturaOpcion !== 'revisar') {
          tx.create(db.collection('gestion_facturas').doc(ref.id), { movimientoId: ref.id, concepto: movement.concepto, centavos: movement.centavos, totalCentavos: movement.fiscal.totalCentavos, proveedor: movement.proveedor, estado: movement.facturaEstado, archivos: movement.archivos, creadoPor: uid, creadoEn: FieldValue.serverTimestamp() });
          notify(tx, db, uid, operation, { title: 'Comprobante por revisar', message: 'Hay una compra que requiere revisión de Administración.', type: 'factura_pendiente', reference: ref.id });
        }
        return { id: ref.id };
      }
      case 'transfer': {
        requirePermission(finance);
        const amount = domain.cents(data.centavos), from = id(data.cuentaOrigenId), to = id(data.cuentaDestinoId);
        if (from === to) fail('Selecciona dos cuentas diferentes.');
        const accounts = await Promise.all([tx.get(db.collection('gestion_cuentas').doc(from)), tx.get(db.collection('gestion_cuentas').doc(to))]);
        for (let i = 0; i < 2; i++) if (!accounts[i].exists && !DEFAULT_ACCOUNTS.some(a => a.id === [from, to][i])) fail('Revisa las cuentas seleccionadas.');
        const ref = db.collection('gestion_movimientos').doc(`empresa_${uid}_${operation}`);
        tx.create(ref, { schemaVersion: 2026, tipo: 'traspaso', subtipo: 'traspaso', centavos: amount, moneda: 'MXN', cuentaOrigenId: from, cuentaDestinoId: to, concepto: text(data.concepto || 'Traspaso entre cuentas propias', 160), fecha: Timestamp.fromDate(date(data.fecha || new Date().toISOString())), creadoPor: uid, creadoEn: FieldValue.serverTimestamp(), operationId: operation });
        return { id: ref.id };
      }
      case 'saveAccount': {
        requirePermission(finance);
        const ref = db.collection('gestion_cuentas').doc(id(data.id || operation)), old = await tx.get(ref);
        const kind = data.tipo;
        if (!['banco', 'efectivo'].includes(kind) || !text(data.nombre)) fail('Escribe el nombre y tipo de cuenta.');
        if (old.exists && old.data().tipo !== kind) fail('No cambies el tipo de una cuenta con historial. Crea otra cuenta.');
        tx.set(ref, { nombre: text(data.nombre, 100), tipo: kind, principal: ref.id === 'banco_principal', saldoInicialCentavos: domain.cents(data.saldoInicialCentavos || 0, { signed: true }), actualizadoPor: uid, actualizadoEn: FieldValue.serverTimestamp() }, { merge: true });
        return { id: ref.id };
      }
      case 'requestPurchase': {
        requirePermission(access.canRequestPurchase(p));
        const product = text(data.producto, 160), reason = text(data.motivo, 2000), projectId = data.proyectoId ? id(data.proyectoId) : '';
        if (!product || !reason) fail('Escribe el producto y para qué se necesita.');
        if (projectId) { const project = await tx.get(db.collection('proyectos').doc(projectId)); if (!project.exists || (!finance && !project.data().encargados?.includes(uid))) fail('El proyecto no está asignado a tu cuenta.'); }
        const ref = db.collection('gestion_compras').doc(`solicitud_${uid}_${operation}`);
        tx.create(ref, { producto: product, motivo: reason, centavosEstimados: domain.cents(data.centavosEstimados), proyectoId: projectId, proveedor: text(data.proveedor), archivos: fileRefs(data.archivos, uid), estado: 'pendiente', creadoPor: uid, creadoEn: FieldValue.serverTimestamp() });
        notify(tx, db, uid, operation, { title: 'Compra por autorizar', message: 'Hay una nueva solicitud de compra.', type: 'compra_pendiente', reference: ref.id });
        return { id: ref.id };
      }
      case 'resolvePurchase': {
        requirePermission(access.canApprovePurchases(p));
        const ref = db.collection('gestion_compras').doc(id(data.id)), old = await tx.get(ref);
        if (!old.exists || !['pendiente', 'informacion_solicitada'].includes(old.data().estado)) fail('La solicitud ya fue resuelta.');
        if (!['aprobada', 'rechazada', 'informacion_solicitada'].includes(data.estado)) fail('Selecciona una resolución.');
        if (data.estado !== 'aprobada' && !text(data.comentario)) fail('Indica el motivo o la información necesaria.');
        tx.update(ref, { estado: data.estado, comentarioAdministracion: text(data.comentario, 2000), resueltoPor: uid, resueltoEn: FieldValue.serverTimestamp() });
        notify(tx, db, uid, operation, { recipient: old.data().creadoPor, title: data.estado === 'aprobada' ? 'Compra aprobada' : data.estado === 'rechazada' ? 'Compra rechazada' : 'Información de compra solicitada', message: 'Abre tu solicitud para consultar la respuesta.', type: `compra_${data.estado}`, reference: ref.id });
        return { id: ref.id };
      }
      case 'purchaseInformation': {
        const ref = db.collection('gestion_compras').doc(id(data.id)), old = await tx.get(ref);
        if (!old.exists || old.data().creadoPor !== uid || old.data().estado !== 'informacion_solicitada' || !text(data.comentario)) fail('La solicitud no espera información de tu cuenta.');
        tx.update(ref, { respuestaSolicitante: text(data.comentario, 2000), estado: 'pendiente', respondidoEn: FieldValue.serverTimestamp() });
        notify(tx, db, uid, operation, { title: 'Solicitud actualizada', message: 'El solicitante respondió la pregunta de compra.', type: 'compra_pendiente', reference: ref.id });
        return { id: ref.id };
      }
      case 'invoiceAttach':
      case 'invoiceState':
      case 'verifyInvoice': {
        requirePermission(finance);
        const ref = db.collection('gestion_facturas').doc(id(data.id)), invoice = await tx.get(ref);
        if (!invoice.exists) fail('La factura ya no está disponible.');
        const movementRef = db.collection('gestion_movimientos').doc(invoice.data().movimientoId), movement = await tx.get(movementRef);
        const config = await tx.get(db.collection('gestion_config').doc('fiscal'));
        if (!movement.exists) fail('No se encontró el movimiento original.');
        if (invoice.data().estado === 'verificada') fail('La factura verificada conserva su comprobación. Registra una corrección administrativa por separado.');
        if (data.action === 'invoiceAttach') {
          const files = fileRefs(data.archivos, uid);
          if (!files.length) fail('Adjunta un archivo XML o PDF.');
          const update = { archivos: [...(invoice.data().archivos || []), ...files].slice(-16), estado: 'verificacion_pendiente', actualizadoPor: uid, actualizadoEn: FieldValue.serverTimestamp() };
          if (parsed) { if (!files.some(f => f.path === data.xmlPath)) fail('Adjunta el XML analizado al expediente.'); update.cfdi = parsed; }
          tx.update(ref, update);
          return { id: ref.id, cfdi: parsed || null };
        }
        if (data.action === 'invoiceState') {
          if (!domain.INVOICE_STATES.includes(data.estado) || data.estado === 'verificada') fail('Selecciona el estado de la factura.');
          tx.update(ref, { estado: data.estado, observaciones: text(data.comentario, 2000), actualizadoPor: uid, actualizadoEn: FieldValue.serverTimestamp() });
          return { id: ref.id };
        }
        const cfdi = invoice.data().cfdi;
        if (!cfdi) fail('Adjunta y analiza el XML timbrado antes de verificar. Una fotografía de ticket no es CFDI.');
        const companyRfc = text(config.data()?.rfc).toUpperCase();
        if (!companyRfc || cfdi.rfcReceptor !== companyRfc) fail('Configura el RFC de la empresa y comprueba que coincida con el receptor.');
        if (Math.abs(cfdi.totalCentavos - (movement.data().fiscal?.totalCentavos || movement.data().centavos)) > 1) fail('El total del XML no coincide con el total registrado.');
        const duplicateRef = db.collection('gestion_cfdi_uuids').doc(cfdi.uuid), duplicate = await tx.get(duplicateRef);
        if (duplicate.exists && duplicate.data().movimientoId !== movement.id) fail('Este UUID ya corresponde a otro movimiento.');
        if (movement.data().fiscal?.tratamiento === 'gravado' && Math.abs((movement.data().fiscal.ivaCentavos || 0) - cfdi.ivaCentavos) > 1) fail('El IVA del XML no coincide con la clasificación fiscal del movimiento.');
        const accredited = data.acreditableConfirmado === true;
        if (accredited && (!data.requisitosAcreditamientoConfirmados || !['gravado', 'tasa_cero'].includes(movement.data().fiscal?.tratamiento))) fail('Contabilidad debe confirmar clasificación, pago y requisitos de acreditamiento.');
        tx.set(duplicateRef, { movimientoId: movement.id, facturaId: ref.id, verificadoPor: uid, verificadoEn: FieldValue.serverTimestamp() });
        tx.update(ref, { estado: 'verificada', verificadoPor: uid, verificadoEn: FieldValue.serverTimestamp(), acreditableConfirmado: accredited, verificacion: 'estructura_importes_rfc_uuid', consultaSAT: 'no_realizada' });
        tx.update(movementRef, { facturaEstado: 'verificada', 'fiscal.acreditableConfirmado': accredited });
        return { id: ref.id };
      }
      case 'classifyMovement': {
        requirePermission(finance);
        const ref = db.collection('gestion_movimientos').doc(id(data.id)), old = await tx.get(ref);
        if (!old.exists || old.data().tipo === 'traspaso') fail('Selecciona un ingreso o gasto.');
        const previous = old.data();
        const fiscal = domain.fiscalData(data.fiscal, previous.centavos);
        const subtype = text(data.subtipo || previous.subtipo || 'otro', 40);
        const allowed = previous.tipo === 'ingreso'
          ? ['venta', 'anticipo', 'parcialidad', 'liquidacion', 'aportacion', 'devolucion', 'otro', 'deposito']
          : ['compra', 'retiro', 'impuesto', 'devolucion', 'otro'];
        if (!allowed.includes(subtype)) fail('El tipo de movimiento no corresponde.');
        const account = data.cuentaId ? id(data.cuentaId) : previous.cuentaId || '';
        if (account) {
          const configured = await tx.get(db.collection('gestion_cuentas').doc(account));
          if (!configured.exists && !DEFAULT_ACCOUNTS.some(a => a.id === account)) fail('Selecciona una cuenta registrada.');
        }
        audit.anterior = { fiscal: previous.fiscal || null, subtipo: previous.subtipo || null, cuentaId: previous.cuentaId || null };
        tx.update(ref, { fiscal, subtipo: subtype, ...(account ? {cuentaId: account} : {}), clasificadoPor: uid, clasificadoEn: FieldValue.serverTimestamp() });
        return { id: ref.id };
      }
      case 'saveFiscalConfig': {
        requirePermission(finance);
        const rfc = text(data.rfc).toUpperCase(), regime = text(data.regimen, 80);
        if (rfc && !/^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$/.test(rfc)) fail('Revisa el RFC.');
        if (!['pendiente', 'actividad_empresarial', 'resico', 'otro'].includes(regime)) fail('Selecciona el régimen confirmado por Contabilidad.');
        const update = { rfc, regimen: regime, confirmada: data.confirmada === true && regime !== 'pendiente', isrMetodo: 'estimacion_contabilidad', actualizadoPor: uid, actualizadoEn: FieldValue.serverTimestamp() };
        for (const k of ['reservaFiscalCentavos', 'reservaMaterialesCentavos', 'reservaInstalacionesCentavos', 'reservaCompromisosCentavos']) update[k] = domain.cents(data[k] ?? 0, { zero: true });
        if (data.month && /^\d{4}-\d{2}$/.test(data.month)) {
          if (data.isrEstimadoCentavos != null) update.isrEstimados = { [data.month]: domain.cents(data.isrEstimadoCentavos, { zero: true }) };
          if (data.declaradoCentavos != null) update.declaraciones = { [data.month]: { declaradoCentavos: domain.cents(data.declaradoCentavos, { zero: true }), registradoPor: uid, registradoEn: FieldValue.serverTimestamp() } };
        }
        tx.set(db.collection('gestion_config').doc('fiscal'), update, { merge: true });
        return { id: 'fiscal' };
      }
      case 'saveBudget': {
        requirePermission(finance);
        const name = text(data.nombre, 160); if (!name) fail('Escribe el nombre del presupuesto.');
        const ref = db.collection('gestion_presupuestos').doc(id(data.id || operation));
        tx.set(ref, { nombre: name, centavos: domain.cents(data.centavos), proyectoId: data.proyectoId ? id(data.proyectoId) : '', categoria: text(data.categoria, 80), mes: /^\d{4}-\d{2}$/.test(data.mes || '') ? data.mes : '', naturaleza: data.naturaleza === 'inversion' ? 'inversion' : 'operacion', actualizadoPor: uid, actualizadoEn: FieldValue.serverTimestamp() }, { merge: true });
        return { id: ref.id };
      }
      case 'saveProjectPlan': {
        requirePermission(finance);
        const ref = db.collection('gestion_proyectos').doc(id(data.proyectoId)), project = await tx.get(db.collection('proyectos').doc(ref.id));
        if (!project.exists) fail('El proyecto no existe.');
        tx.set(ref, { precioVentaCentavos: domain.cents(data.precioVentaCentavos), precioVentaNetoCentavos: data.precioVentaNetoCentavos == null ? null : domain.cents(data.precioVentaNetoCentavos), costosPendientesCentavos: domain.cents(data.costosPendientesCentavos || 0, { zero: true }), costosEstimadosCentavos: domain.cents(data.costosEstimadosCentavos || 0, { zero: true }), baseComparacion: 'precio_neto_menos_costos_registrados_sin_iva_acreditable', actualizadoPor: uid, actualizadoEn: FieldValue.serverTimestamp() });
        return { id: ref.id };
      }
      case 'importStatement': {
        requirePermission(finance);
        const accountId = id(data.cuentaId), rows = data.rows;
        if (!Array.isArray(rows) || !rows.length || rows.length > 100) fail('Importa entre 1 y 100 renglones por archivo.');
        const clean = rows.map(r => ({ fecha: date(r.fecha).toISOString(), referencia: text(r.referencia, 200), centavos: domain.cents(r.centavos, { signed: true }) }));
        const refs = clean.map(r => db.collection('gestion_conciliaciones').doc(domain.hash([accountId, r])));
        if (new Set(refs.map(r => r.id)).size !== refs.length) fail('Hay renglones idénticos. Sepáralos con una referencia bancaria única antes de importar.');
        const old = await Promise.all(refs.map(r => tx.get(r)));
        for (let i = 0; i < refs.length; i++) if (!old[i].exists) tx.create(refs[i], { ...clean[i], cuentaId: accountId, mes: clean[i].fecha.slice(0, 7), estado: 'pendiente', creadoPor: uid, creadoEn: FieldValue.serverTimestamp() });
        return { id: operation, imported: old.filter(s => !s.exists).length };
      }
      case 'reconcile': {
        requirePermission(finance);
        const statementRef = db.collection('gestion_conciliaciones').doc(id(data.id)), movementRef = db.collection('gestion_movimientos').doc(id(data.movimientoId));
        const [statement, movement] = await Promise.all([tx.get(statementRef), tx.get(movementRef)]);
        if (!statement.exists || !movement.exists) fail('Revisa el renglón y movimiento.');
        const s = statement.data(), m = movement.data();
        if (s.estado === 'conciliado' || m.conciliacionesPorCuenta?.[s.cuentaId] || m.conciliacionId) fail('Este registro ya tiene una conciliación para esta cuenta.');
        const amount = m.tipo === 'traspaso' ? m.cuentaOrigenId === s.cuentaId ? -m.centavos : m.cuentaDestinoId === s.cuentaId ? m.centavos : null : m.cuentaId === s.cuentaId ? (m.tipo === 'ingreso' ? 1 : -1) * m.centavos : null;
        if (amount !== s.centavos) fail('La cuenta y el importe del banco deben coincidir exactamente con el movimiento.');
        tx.update(statementRef, { estado: 'conciliado', movimientoId: movement.id, conciliadoPor: uid, conciliadoEn: FieldValue.serverTimestamp() });
        tx.update(movementRef, { [`conciliacionesPorCuenta.${s.cuentaId}`]: statement.id, conciliadoPor: uid, conciliadoEn: FieldValue.serverTimestamp() });
        return { id: statement.id };
      }
      case 'recordBankBalance': {
        requirePermission(finance);
        const ref = db.collection('gestion_cuentas').doc(id(data.cuentaId));
        const old = await tx.get(ref);
        if ((!old.exists && ref.id !== 'banco_principal') || (old.exists && old.data().tipo !== 'banco')) fail('Selecciona una cuenta bancaria.');
        if (!text(data.referencia)) fail('Escribe la referencia del estado de cuenta revisado.');
        const values = { ...(old.exists ? {} : DEFAULT_ACCOUNTS[0]), saldoBancarioRevisadoCentavos: domain.cents(data.centavos, { signed: true }), fechaSaldoBancario: Timestamp.fromDate(date(data.fecha)), referenciaEstadoCuenta: text(data.referencia), revisadoPor: uid, revisadoEn: FieldValue.serverTimestamp() };
        delete values.id;
        tx.set(ref, values, { merge: true });
        return { id: ref.id };
      }
      default: throw new HttpsError('invalid-argument', 'Acción financiera no disponible.');
    }
  });
}
const enterpriseFinance = onCall({ timeoutSeconds: 60, memory: '512MiB' }, async request => {
  try { return await runFinance(request); }
  catch (e) { if (e instanceof HttpsError) throw e; if (/importe|XML|CFDI|fiscal|IVA|UUID|RFC|comprobante|tasa|pagado|total|centavos|Selecciona|Revisa/.test(e.message || '')) throw new HttpsError('invalid-argument', e.message); console.error('enterpriseFinance failure', e.code || e.name); throw new HttpsError('internal', 'No se confirmó la operación. Reintenta con el mismo formulario para evitar duplicados.'); }
});
module.exports = { enterpriseFinance, runFinance, DEFAULT_ACCOUNTS };
