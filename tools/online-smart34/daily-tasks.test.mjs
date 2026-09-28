import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDailyTasksService } from './daily-tasks.mjs';

class Fault extends Error { constructor(message, status) { super(message); this.status = status; } }
const day = '20260928';
const users = { admin: { uid: 'admin', role: 'admin', name: 'Administración QA' }, master: { uid: 'master', role: 'maestro', name: 'Maestro QA' }, worker: { uid: 'worker', role: 'trabajador', name: 'Trabajador QA' }, warehouse: { uid: 'warehouse', role: 'almacenista', name: 'Almacén QA' }, other: { uid: 'other', role: 'trabajador', name: 'Otra persona' } };
function fixture() {
  const tables = new Map(), files = new Map(); let serial = 0, failUpload = false, failWrite = false;
  const db = {
    async list(table, { limit }) { const items = tables.get(table) || []; return { items: structuredClone(items.slice(0, limit)), ...(items.length > limit ? { nextToken: 'more' } : {}) }; },
    async add(table, rows) {
      if (failWrite) return [null];
      const items = tables.get(table) || []; tables.set(table, items);
      return rows.map(row => { const id = `id-${++serial}`; items.push({ ...structuredClone(row), id }); return id; });
    },
  };
  const storage = {
    async write(rows) { if (failUpload) return [false]; return rows.map(row => { files.set(row.path, row); return true; }); },
    async url(paths) { return paths.map(path => ({ path, url: `https://isolated.example.invalid/${path}?signed=yes` })); },
  };
  const fetcher = async url => {
    assert.ok(url.startsWith('https://firestore.googleapis.com/'));
    const uid = decodeURIComponent(url.split('/usuarios/')[1].split('?')[0]), user = users[uid];
    return { ok: !!user, status: user ? 200 : 404, json: async () => ({ fields: { nombre: { stringValue: user?.name }, rol: { stringValue: user?.role }, activo: { booleanValue: true } } }) };
  };
  const call = (action, body = {}, actor = users.worker) => createDailyTasksService({ db, storage, Fault, fetcher, clock: () => new Date('2026-09-28T15:00:00Z') })(action, { day, ...body }, actor, { token: 'isolated-token' });
  const create = (userId = 'worker', actor = users.master, operationId = 'create-1') => call('daily-create', { title: 'Preparar el taller', details: 'Ordenar y adjuntar evidencia.', userId, operationId }, actor);
  return { call, create, tables, files, failUpload(v) { failUpload = v; }, failWrite(v) { failWrite = v; } };
}

test('administrator and master assign to every active role; recipients and authors see persistent tasks', async () => {
  const f = fixture();
  for (const actor of [users.admin, users.master]) for (const recipient of [users.admin, users.master, users.worker, users.warehouse]) {
    const { task } = await f.create(recipient.uid, actor, `${actor.uid}-${recipient.uid}`);
    assert.equal((await f.call('daily-read', { taskId: task.taskId }, recipient)).task.title, task.title);
    assert.ok((await f.call('daily-list', {}, recipient)).items.some(t => t.taskId === task.taskId));
    assert.equal((await f.call('daily-read', { taskId: task.taskId }, actor)).task.userId, recipient.uid);
  }
  await assert.rejects(f.create('other', users.worker), { status: 403 });
  await assert.rejects(f.create('other', users.warehouse), { status: 403 });
  await assert.rejects(f.create('missing'), { status: 403 });
});

test('a recipient uploads evidence, completes, and the assigning master rereads the attachment and status', async () => {
  const f = fixture(), { task } = await f.create();
  await assert.rejects(f.call('daily-complete', { taskId: task.taskId, operationId: 'finish' }), /evidencia/);
  const evidence = { taskId: task.taskId, operationId: 'photo-1', name: 'trabajo.png', base64: Buffer.from([137,80,78,71,13,10,26,10,0,0,0]).toString('base64') };
  const saved = await f.call('daily-evidence', evidence);
  assert.equal(saved.task.evidenceCount, 1); assert.equal(saved.task.status, 'en_progreso');
  assert.ok(saved.task.evidence[0].url.startsWith('https://isolated.example.invalid/'));
  await f.call('daily-evidence', evidence); assert.equal(f.files.size, 1);
  await f.call('daily-progress', { taskId: task.taskId, operationId: 'note', comment: 'Trabajo revisado y ordenado.' });
  await f.call('daily-complete', { taskId: task.taskId, operationId: 'finish' });
  const reviewed = await f.call('daily-read', { taskId: task.taskId }, users.master);
  assert.equal(reviewed.task.status, 'completado'); assert.equal(reviewed.task.evidenceCount, 1);
  assert.ok(reviewed.task.history.some(e => e.comment === 'Trabajo revisado y ordenado.'));
  assert.equal(reviewed.task.completedAt, '2026-09-28T15:00:00.000Z');
  await assert.rejects(f.call('daily-progress', { taskId: task.taskId, operationId: 'late', comment: 'Late' }), /terminada/);
});

test('unrelated users never receive attachments and creators cannot impersonate the recipient', async () => {
  const f = fixture(), { task } = await f.create();
  assert.equal((await f.call('daily-list', {}, users.other)).items.length, 0);
  for (const action of ['daily-read', 'daily-evidence', 'daily-complete']) await assert.rejects(f.call(action, { taskId: task.taskId }, users.other), { status: 403 });
  for (const actor of [users.master, users.admin]) await assert.rejects(f.call('daily-evidence', { taskId: task.taskId }, actor), { status: 403 });
  await assert.rejects(f.call('daily-read', { taskId: '../anything' }), /inválida/);
});

test('retries and concurrent create taps produce one logical task and do not reset recipient progress', async () => {
  const f = fixture();
  const created = await Promise.all(Array.from({ length: 5 }, () => f.create()));
  assert.equal(new Set(created.map(r => r.task.taskId)).size, 1);
  const taskId = created[0].task.taskId;
  await f.call('daily-progress', { taskId, operationId: 'started', comment: 'Ya empecé.' });
  assert.equal((await f.create()).task.status, 'en_progreso');
  assert.equal((await f.call('daily-list')).items.length, 1);
  await assert.rejects(f.create('warehouse'), { status: 409 });
});

test('failed upload or persistence does not report an assignment or completed evidence', async () => {
  const f = fixture(); f.failWrite(true);
  await assert.rejects(f.create(), { status: 503 });
  f.failWrite(false); const { task } = await f.create(); f.failUpload(true);
  await assert.rejects(f.call('daily-evidence', { taskId: task.taskId, operationId: 'pdf', name: 'evidencia.pdf', base64: Buffer.from('%PDF-1.7\nsynthetic isolated test').toString('base64') }), { status: 503 });
  assert.equal((await f.call('daily-read', { taskId: task.taskId })).task.evidenceCount, 0);
  await assert.rejects(f.call('daily-evidence', { taskId: task.taskId, operationId: 'script', name: 'photo.jpg', base64: Buffer.from('<script>test</script>').toString('base64') }), /JPG/);
});
