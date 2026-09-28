import test from 'node:test';
import assert from 'node:assert/strict';
import { createAttendanceService, decodeValue, encodeValue, dayKey, ZONES } from './attendance.mjs';
class Fault extends Error { constructor(message, status) { super(message); this.status = status; } }
const worker = { uid: 'worker', role: 'trabajador', name: 'QA worker', horaEntrada: '09:00', toleranciaMinutos: 11 };
const admin = { uid: 'admin', role: 'admin', name: 'QA admin' };
const day = '20260928';
function fixture() {
  const tables = new Map(), records = new Map();
  let now = new Date('2026-09-28T15:00:00Z'), serial = 0, revision = 0, failAdd = false, failCommit = false, conflict = false, quota = false;
  const db = {
    async list(name, { limit, nextToken } = {}) {
      if (quota) throw Object.assign(new Error('quota'), { statusCode: 429 });
      const rows = tables.get(name) || [], start = Number(nextToken || 0), end = start + limit;
      return { items: structuredClone(rows.slice(start, end)), ...(end < rows.length ? { nextToken: String(end) } : {}) };
    },
    async add(name, rows) {
      if (failAdd) return [null];
      const entries = tables.get(name) || []; tables.set(name, entries);
      return rows.map(row => { const id = `receipt-${++serial}`; entries.push({ ...structuredClone(row), id }); return id; });
    },
  };
  const response = (body, status = 200) => ({ ok: status === 200, status, json: async () => body });
  const fetcher = async (url, options) => {
    const body = JSON.parse(options.body), token = options.headers.Authorization;
    if (url.endsWith(':runQuery')) {
      const uid = body.structuredQuery.where.fieldFilter.value.stringValue;
      const name = body.structuredQuery.startAt.values[0].referenceValue;
      assert.equal(body.structuredQuery.orderBy[0].direction, 'DESCENDING');
      assert.equal(body.structuredQuery.startAt.before, true);
      assert.match(name, new RegExp(`/asistencias/${uid}_[0-9]{8}$`));
      assert.equal(body.structuredQuery.limit, 1);
      if (token !== 'Bearer admin-token' && token !== `Bearer ${uid}-token`) return response({}, 403);
      const old = records.get(name);
      return response(old ? [{ document: { name, fields: Object.fromEntries(Object.entries(old.data).map(([k, v]) => [k, encodeValue(v, k)])), updateTime: old.version } }] : [{ readTime: now.toISOString() }]);
    }
    assert.ok(url.endsWith(':commit'));
    if (token !== 'Bearer admin-token') return response({}, 403);
    if (failCommit) return response({}, 503);
    const write = body.writes[0], old = records.get(write.update.name);
    if (conflict || (old ? write.currentDocument.updateTime !== old.version : write.currentDocument.exists !== false)) return response({}, 409);
    const patch = Object.fromEntries(Object.entries(write.update.fields).map(([k, v]) => [k, decodeValue(v)]));
    assert.deepEqual(write.updateMask.fieldPaths.sort(), Object.keys(patch).sort());
    for (const protectedField of ['listaBonos', 'listaMultas', 'observacionesAdmin', 'observacionesTrabajador', 'sueldoBaseSemanal']) assert.ok(!write.updateMask.fieldPaths.includes(protectedField));
    records.set(write.update.name, { data: { ...old?.data, ...patch }, version: `v${++revision}` });
    return response({ commitTime: now.toISOString(), writeResults: [{ updateTime: `v${revision}` }] });
  };
  const call = (action, b = {}, u = worker) => createAttendanceService({ db, Fault, fetcher, clock: () => now })(action, b, u, { token: `${u.uid}-token` });
  const move = (movement, extra = {}) => call('attendance-record', { movement, latitud: ZONES[0][0], longitud: ZONES[0][1], ...extra });
  const sync = () => call('attendance-sync-page', { day }, admin);
  const stored = () => [...records.values()][0]?.data;
  return { call, move, sync, stored, tables, records,
    time(value) { now = new Date(value); },
    failWrite(value) { failAdd = value; }, failSync(value) { failCommit = value; }, conflict(value) { conflict = value; }, quota(value) { quota = value; },
    seed(data) { records.set(`projects/saunastiloapp-17e15/databases/(default)/documents/asistencias/worker_${day}`, { data, version: `v${++revision}` }); },
  };
}

test('complete day persists across service restarts and reaches the original payroll document with administrator approval', async () => {
  const f = fixture();
  const entry = await f.move('entrada', { horaEntrada: '1999-01-01', role: 'admin', trabajadorId: 'other' });
  assert.equal(entry.data.horaEntrada, '2026-09-28T15:00:00.000Z');
  assert.equal(entry.pendingSync, true);
  assert.equal((await f.call('attendance-state')).data.horaEntrada, entry.data.horaEntrada);
  await f.sync(); assert.equal(f.stored().horaEntrada, entry.data.horaEntrada);
  f.time('2026-09-28T20:00:00Z'); await f.move('solicitar_comida');
  await assert.rejects(f.move('regreso_comida'), /autoriz/);
  f.time('2026-09-28T20:05:00Z');
  await f.call('attendance-approve', { userId: 'worker', day }, admin);
  f.time('2026-09-28T20:35:00Z'); await f.move('regreso_comida');
  f.time('2026-09-29T01:00:00Z'); await f.move('salida'); await f.sync();
  const saved = f.stored();
  assert.equal(saved.regresoComidaReal, '2026-09-28T20:35:00.000Z');
  assert.equal(saved.horaSalida, '2026-09-29T01:00:00.000Z');
  assert.equal(saved.resumenJornada.minutosEntreEntradaYSalida, 600);
  assert.equal(saved.resumenJornada.minutosComida, 30);
  assert.equal(saved.resumenJornada.minutosSinComida, 570);
  const reread = await f.call('attendance-history', { days: [day] });
  assert.equal(reread.items[0].pendingSync, false);
  assert.equal(reread.items[0].data.horaSalida, saved.horaSalida);
  assert.equal((await f.move('entrada')).data.horaEntrada, entry.data.horaEntrada);
  assert.equal((await f.call('attendance-approve', { userId: 'worker', day }, admin)).yaRegistrada, true);
});

test('workers cannot read peers, synchronize, authorize meals or register for administration', async () => {
  const f = fixture();
  for (const action of ['attendance-state', 'attendance-history', 'attendance-record']) await assert.rejects(f.call(action, { userId: 'other' }), { status: 403 });
  await assert.rejects(f.call('attendance-sync-page'), { status: 403 });
  await assert.rejects(f.call('attendance-approve'), { status: 403 });
  await assert.rejects(f.call('attendance-record', { movement: 'entrada' }, admin), { status: 403 });
  await assert.rejects(f.move('entrada', { latitud: 0, longitud: 0 }), /zona autorizada/);
  await assert.rejects(f.move('salida'), /Primero/);
  await assert.rejects(f.move('entrada', { day: '20260927' }), /Cambió el día/);
  await assert.rejects(f.call('attendance-state', { day: '20260230' }), /fecha válida/);
  assert.equal(f.tables.size, 0);
});

test('concurrent taps preserve one effective original time; no event is replaced', async () => {
  const f = fixture();
  const results = await Promise.all(Array.from({ length: 8 }, () => f.move('entrada')));
  assert.equal(new Set(results.map(r => r.data.horaEntrada)).size, 1);
  await f.sync();
  f.time('2026-09-28T16:00:00Z');
  assert.equal((await f.move('entrada')).data.horaEntrada, '2026-09-28T15:00:00.000Z');
  assert.equal(f.stored().horaEntrada, '2026-09-28T15:00:00.000Z');
});

test('failed storage never reports success; failed admin sync leaves durable receipts recoverable', async () => {
  const f = fixture(); f.failWrite(true);
  await assert.rejects(f.move('entrada'), { status: 503 });
  assert.equal((await f.call('attendance-state')).data.horaEntrada, undefined);
  f.failWrite(false); await f.move('entrada'); f.failSync(true);
  await assert.rejects(f.sync(), { status: 503 });
  assert.equal((await f.call('attendance-state')).pendingSync, true);
  f.failSync(false); await f.sync();
  assert.equal((await f.call('attendance-state')).pendingSync, false);
  f.quota(true); await assert.rejects(f.call('attendance-state'), { statusCode: 429 });
});

test('administrative corrections, justifications, bonuses and notes survive synchronization; conflicts are not overwritten', async () => {
  const f = fixture();
  f.seed({ trabajadorId: 'worker', fecha: '2026-09-28T18:00:00.000Z', estatus: 'justificado', estatusJustificacion: 'aprobada', listaBonos: [{ monto: 100 }], observacionesAdmin: 'Revisado', observacionesTrabajador: 'Mi nota' });
  await f.move('entrada'); f.conflict(true); await assert.rejects(f.sync(), { status: 409 });
  f.conflict(false); await f.sync();
  f.seed({ ...f.stored(), horaEntrada: '2026-09-28T14:55:00.000Z' });
  f.time('2026-09-29T01:00:00Z'); await f.move('salida'); await f.sync();
  assert.equal(f.stored().horaEntrada, '2026-09-28T14:55:00.000Z');
  assert.equal(f.stored().estatus, 'justificado');
  assert.deepEqual(f.stored().listaBonos, [{ monto: 100 }]);
  assert.equal(f.stored().observacionesAdmin, 'Revisado');
  assert.equal(f.stored().observacionesTrabajador, 'Mi nota');
  f.seed({ ...f.stored(), horaEntrada: null });
  await f.sync(); assert.equal(f.stored().horaEntrada, null);
});

test('exit during an unfinished meal preserves the real exit and marks the missing return', async () => {
  const f = fixture(); await f.move('entrada');
  f.time('2026-09-28T20:00:00Z'); await f.move('solicitar_comida');
  await f.call('attendance-approve', { userId: 'worker', day }, admin);
  f.time('2026-09-28T21:00:00Z'); await f.move('salida'); await f.sync();
  assert.equal(f.stored().regresoComidaReal, undefined);
  assert.ok(f.stored().resumenJornada.incidencias.includes('comida_sin_regreso'));
  assert.equal(f.stored().resumenJornada.minutosSinComida, null);
  await assert.rejects(f.move('regreso_comida'), /jornada abierta/);
});

test('Mexico date rolls over at 06:00 UTC, not the device date', () => {
  assert.equal(dayKey(new Date('2026-09-29T05:59:59Z')), day);
  assert.equal(dayKey(new Date('2026-09-29T06:00:00Z')), '20260929');
});

test('simple manual day needs no coordinates or meal approval, preserves server times and marks location unverified', async () => {
  for (const role of ['trabajador','maestro','almacenista','admin']) {
    const f = fixture(), person = {...worker, role};
    const manual = movement => f.call('attendance-record', {movement, manual: true}, person);
    const first = await manual('entrada');
    assert.equal(first.supportsManual, true);
    assert.equal(first.data.registroManual, true);
    assert.equal(first.data.ubicacionValida, false);
    assert.equal(first.data.latitudRegistro, null);
    f.time('2026-09-28T20:00:00Z'); await manual('salida_comida');
    f.time('2026-09-28T20:30:00Z'); await manual('regreso_comida');
    f.time('2026-09-29T01:00:00Z'); const last = await manual('salida');
    assert.equal(last.data.estatusComida,'finalizada');
    assert.equal(last.data.ubicacionRegresoComidaValida,false);
    assert.equal(last.data.resumenJornada.minutosComida,30);
    assert.equal((await manual('entrada')).data.horaEntrada,first.data.horaEntrada);
    await f.sync(); assert.equal(f.stored().horaSalida,last.data.horaSalida);
  }
});

test('manual mode never impersonates another account, backdates or reports a failed receipt as saved', async () => {
  const f=fixture();
  await assert.rejects(f.call('attendance-record',{movement:'entrada',manual:true,userId:'other'}),{status:403});
  await assert.rejects(f.call('attendance-record',{movement:'entrada',manual:true,day:'20260927'}),{status:409});
  f.failWrite(true);
  await assert.rejects(f.call('attendance-record',{movement:'entrada',manual:true}),{status:503});
  assert.equal((await f.call('attendance-state')).data.horaEntrada,undefined);
});
