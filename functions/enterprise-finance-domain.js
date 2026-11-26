'use strict';

const crypto = require('node:crypto');
const { XMLParser, XMLValidator } = require('fast-xml-parser');

const MAX_CENTS = 99999999999;
const INVOICE_STATES = ['pendiente', 'solicitada', 'esperando_proveedor', 'recibida', 'verificacion_pendiente', 'verificada', 'requiere_correccion', 'no_facturable'];
const TREATMENTS = ['pendiente', 'gravado', 'tasa_cero', 'exento', 'no_objeto'];
function cents(value, { zero = false, signed = false } = {}) {
  if (!Number.isSafeInteger(value) || Math.abs(value) > MAX_CENTS || (!signed && value < (zero ? 0 : 1))) throw new Error('El importe debe expresarse en centavos válidos.');
  return value;
}
function decimalCents(value) {
  const s = String(value ?? '').trim();
  if (!/^\d{1,9}(\.\d{1,6})?$/.test(s)) throw new Error('Importe fiscal inválido.');
  const [whole, fraction = ''] = s.split('.');
  return cents(Number(whole) * 100 + Number((fraction + '00').slice(0, 2)) + (Number(fraction[2] || 0) >= 5 ? 1 : 0), { zero: true });
}
function hash(value) { return crypto.createHash('sha256').update(typeof value === 'string' ? value : canonical(value)).digest('hex'); }
function canonical(v) {
  if (Array.isArray(v)) return `[${v.map(canonical).join(',')}]`;
  if (v && typeof v === 'object') return `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonical(v[k])}`).join(',')}}`;
  return JSON.stringify(v);
}
function fiscalData(input, paid) {
  const d = input || {}, treatment = d.tratamiento || 'pendiente';
  if (!TREATMENTS.includes(treatment)) throw new Error('Selecciona el tratamiento fiscal.');
  const total = cents(d.totalCentavos ?? paid);
  if (paid > total) throw new Error('El importe pagado no puede superar el total del comprobante.');
  if (treatment === 'pendiente') return { tratamiento: treatment, totalCentavos: total, pendienteCentavos: total - paid, acreditableConfirmado: false };
  const rate = treatment === 'gravado' ? d.tasaBps ?? 1600 : 0;
  if (!Number.isInteger(rate) || rate < 0 || rate > 1600 || (treatment === 'gravado' && rate === 0)) throw new Error('Revisa la tasa de IVA.');
  const retainedVat = cents(d.retencionIvaCentavos ?? 0, { zero: true });
  const retainedIsr = cents(d.retencionIsrCentavos ?? 0, { zero: true });
  const gross = total + retainedVat + retainedIsr;
  const base = d.baseCentavos == null ? Math.round(gross * 10000 / (10000 + rate)) : cents(d.baseCentavos, { zero: true });
  const vat = Math.round(base * rate / 10000);
  if (Math.abs(base + vat - retainedVat - retainedIsr - total) > 1 || retainedVat > vat) throw new Error('La base, el IVA, las retenciones y el total no coinciden.');
  return { tratamiento: treatment, tasaBps: rate, baseCentavos: base, ivaCentavos: vat, retencionIvaCentavos: retainedVat, retencionIsrCentavos: retainedIsr, totalCentavos: total, pendienteCentavos: total - paid, acreditableConfirmado: false };
}
function effectiveTax(movement) {
  const f = movement.fiscal || {};
  if (!TREATMENTS.includes(f.tratamiento) || f.tratamiento === 'pendiente' || !Number.isSafeInteger(f.totalCentavos) || f.totalCentavos <= 0) return null;
  const ratio = Math.min(1, Math.max(0, movement.centavos / f.totalCentavos));
  return { base: Math.round((f.baseCentavos || 0) * ratio), vat: Math.round((f.ivaCentavos || 0) * ratio), retainedVat: Math.round((f.retencionIvaCentavos || 0) * ratio), retainedIsr: Math.round((f.retencionIsrCentavos || 0) * ratio) };
}
function financialSummary(rows, config = {}, month = '') {
  const s = { ingresos: 0, egresos: 0, ventasCobradas: 0, baseCobrada: 0, ivaCobrado: 0, ivaAcreditable: 0, ivaRetenido: 0, impuestosPagados: 0, sinClasificar: 0, sinComprobar: 0 };
  for (const m of rows) {
    if (m.tipo === 'traspaso' || m.subtipo === 'traspaso') continue;
    if (m.tipo === 'ingreso') s.ingresos += m.centavos || 0;
    if (m.tipo === 'egreso') s.egresos += m.centavos || 0;
    if (m.tipo === 'egreso' && m.subtipo === 'impuesto') s.impuestosPagados += m.centavos || 0;
    const tax = effectiveTax(m);
    if (!tax || !m.subtipo || (m.tipo !== 'traspaso' && !m.cuentaId)) s.sinClasificar++;
    // Deposits and owner contributions are never silently classified as sales.
    if (m.tipo === 'ingreso' && ['anticipo', 'parcialidad', 'liquidacion', 'venta'].includes(m.subtipo)) {
      s.ventasCobradas += m.centavos || 0;
      if (tax) { s.baseCobrada += tax.base; s.ivaCobrado += tax.vat; s.ivaRetenido += tax.retainedVat; }
    }
    if (m.tipo === 'egreso' && m.facturaEstado !== 'verificada') s.sinComprobar++;
    if (m.tipo === 'egreso' && tax && m.facturaEstado === 'verificada' && m.fiscal?.acreditableConfirmado === true) s.ivaAcreditable += Math.max(0, tax.vat - tax.retainedVat);
  }
  s.ivaEstimadoPorPagar = Math.max(0, s.ivaCobrado - s.ivaRetenido - s.ivaAcreditable);
  s.impuestosDeclarados = config.declaraciones?.[month]?.declaradoCentavos ?? null;
  s.isrEstimado = config.confirmada === true && ['actividad_empresarial','resico','otro'].includes(config.regimen) && config.isrMetodo === 'estimacion_contabilidad' ? config.isrEstimados?.[month] ?? null : null;
  return s;
}
function accountBalances(rows, accounts = []) {
  const result = new Map(accounts.map(a => [a.id, { ...a, saldoRegistrado: a.saldoInicialCentavos || 0 }]));
  const add = (id, amount) => {
    id ||= 'historico_sin_cuenta';
    if (!result.has(id)) result.set(id, { id, nombre: id === 'historico_sin_cuenta' ? 'Histórico sin cuenta asignada' : id, tipo: 'sin_clasificar', saldoRegistrado: 0 });
    result.get(id).saldoRegistrado += amount;
  };
  for (const m of rows) {
    if (m.tipo === 'traspaso') { add(m.cuentaOrigenId, -m.centavos); add(m.cuentaDestinoId, m.centavos); }
    else add(m.cuentaId, (m.tipo === 'ingreso' ? 1 : -1) * (m.centavos || 0));
  }
  return [...result.values()];
}
function projectProfitability(project, rows, plan = {}) {
  const own = rows.filter(m => m.proyectoId === project.id && m.tipo !== 'traspaso');
  const costs = own.filter(m => m.tipo === 'egreso' && m.subtipo !== 'impuesto');
  const received = own.filter(m => m.tipo === 'ingreso' && ['anticipo', 'parcialidad', 'liquidacion', 'venta'].includes(m.subtipo)).reduce((s, m) => s + m.centavos, 0);
  const netCost = costs.reduce((s, m) => {
    const tax = effectiveTax(m);
    const credited = m.facturaEstado === 'verificada' && m.fiscal?.acreditableConfirmado && tax ? Math.max(0, tax.vat - tax.retainedVat) : 0;
    return s + m.centavos - credited;
  }, 0);
  const sale = plan.precioVentaCentavos ?? null, netSale = plan.precioVentaNetoCentavos ?? null;
  const pending = plan.costosPendientesCentavos || 0, estimated = plan.costosEstimadosCentavos || 0;
  return { id: project.id, titulo: project.titulo || project.nombre || 'Proyecto', precioVentaCentavos: sale, precioVentaNetoCentavos: netSale, anticiposCentavos: received, saldoPorCobrar: sale == null ? null : Math.max(0, sale - received), costoRegistrado: netCost, costosPendientes: pending, costosEstimados: estimated, margenEstimado: netSale == null ? null : netSale - netCost - pending - estimated, categorias: Object.fromEntries([...new Set(costs.map(m => m.categoria || 'Otros'))].map(c => [c, costs.filter(m => (m.categoria || 'Otros') === c).reduce((s, m) => s + m.centavos, 0)])) };
}
function parseCfdi(xml) {
  if (typeof xml !== 'string' || Buffer.byteLength(xml) > 2 * 1024 * 1024 || /<!DOCTYPE|<!ENTITY/i.test(xml) || XMLValidator.validate(xml) !== true) throw new Error('El XML no es válido; se rechazan entidades y documentos externos.');
  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_', removeNSPrefix: true, parseAttributeValue: false, processEntities: false });
  const root = parser.parse(xml).Comprobante;
  if (!root || Array.isArray(root) || !['4.0', '3.3'].includes(root['@_Version'])) throw new Error('Se requiere un CFDI 3.3 o 4.0.');
  const stamp = root.Complemento?.TimbreFiscalDigital;
  if (!stamp || Array.isArray(stamp)) throw new Error('El XML no contiene un timbre fiscal único.');
  const uuid = String(stamp['@_UUID'] || '').toUpperCase();
  const issuer = root.Emisor?.['@_Rfc'], receiver = root.Receptor?.['@_Rfc'];
  if (!/^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/.test(uuid) || !/^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$/.test(issuer || '') || !/^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$/.test(receiver || '')) throw new Error('Revisa el UUID y los RFC del XML.');
  if (root['@_Moneda'] !== 'MXN' || root['@_TipoDeComprobante'] !== 'I') throw new Error('Esta verificación requiere un CFDI de ingreso en MXN; complementos y egresos requieren revisión de Contabilidad.');
  const total = decimalCents(root['@_Total']);
  const subtotal = decimalCents(root['@_SubTotal']);
  const discount = decimalCents(root['@_Descuento'] || 0);
  const transferred = decimalCents(root.Impuestos?.['@_TotalImpuestosTrasladados'] || 0);
  const retained = decimalCents(root.Impuestos?.['@_TotalImpuestosRetenidos'] || 0);
  if (Math.abs(subtotal - discount + transferred - retained - total) > 2) throw new Error('Los importes del XML no coinciden con su total.');
  const transfers = root.Impuestos?.Traslados?.Traslado;
  const taxRows = transfers ? (Array.isArray(transfers) ? transfers : [transfers]) : [];
  const vat = taxRows.filter(t => t['@_Impuesto'] === '002').reduce((s, t) => s + decimalCents(t['@_Importe'] || 0), 0);
  return { uuid, rfcEmisor: issuer, rfcReceptor: receiver, totalCentavos: total, subtotalCentavos: subtotal, descuentoCentavos: discount, impuestosTrasladadosCentavos: transferred, impuestosRetenidosCentavos: retained, ivaCentavos: vat, version: root['@_Version'], metodoPago: root['@_MetodoPago'] || '', fecha: root['@_Fecha'] || '', xmlSha256: hash(xml), comprobacionSAT: 'no_consultada' };
}
module.exports = { MAX_CENTS, INVOICE_STATES, TREATMENTS, cents, decimalCents, hash, canonical, fiscalData, effectiveTax, financialSummary, accountBalances, projectProfitability, parseCfdi };
