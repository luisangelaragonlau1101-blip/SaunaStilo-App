import { createHash, randomUUID } from 'node:crypto';

const ROOT =
  'https://firestore.googleapis.com/v1/projects/saunastiloapp-17e15/databases/(default)/documents';
const ROLES = ['admin', 'maestro', 'almacenista', 'trabajador'];
const hash = (text) => createHash('sha256').update(text).digest('hex');

export function createDailyTasksService({
  db,
  storage,
  Fault,
  fetcher = fetch,
  clock = () => new Date(),
  notify = async () => ({ notificationSaved: true }),
}) {
  const check = (ok, message, status = 400) => {
    if (!ok) throw new Fault(message, status);
  };
  const text = (value, max, min = 1) => {
    check(
      typeof value === 'string' &&
        value.trim().length >= min &&
        value.trim().length <= max,
      'Revisa los campos de la tarea.',
    );
    return value.trim();
  };
  const assigner = (u) => ['admin', 'maestro'].includes(u.role);
  const canRead = (task, u) =>
    u.role === 'admin' || task.createdBy === u.uid || task.userId === u.uid;
  const date = (value) => {
    check(
      typeof value === 'string' && /^20\d{4}(\d{2})?$/.test(value),
      'Selecciona el día de la tarea.',
    );
    const d = new Date(
      `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.length === 6 ? '01' : value.slice(6)}T12:00:00Z`,
    );
    check(
      Number.isFinite(d.getTime()) &&
        d.toISOString().slice(0, value.length === 6 ? 7 : 10).replaceAll('-', '') === value,
      'Fecha inválida.',
    );
    return value;
  };
  const taskTable = (day) => `sauna-daily-tasks:${day}`;
  const eventTable = (id) => `sauna-daily-task-events:${id}`;
  async function list(table) {
    const result = await db.list(table, { limit: 100 });
    check(
      !result.nextToken,
      'El historial de este día requiere revisión. No se ocultaron registros.',
      409,
    );
    return result.items;
  }
  async function tasks(day) {
    const rows = await list(taskTable(day)),
      unique = new Map();
    for (const row of rows.sort(
      (a, b) =>
        a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id),
    ))
      if (!unique.has(row.taskId)) unique.set(row.taskId, row);
    return [...unique.values()];
  }
  async function getTask(day, id, u) {
    check(
      typeof id === 'string' && /^[a-f0-9]{64}$/.test(id),
      'Tarea inválida.',
    );
    const task = (await tasks(day)).find((t) => t.taskId === id);
    check(
      task && canRead(task, u),
      'Esta tarea no está disponible para tu cuenta.',
      403,
    );
    return task;
  }
  async function state(task, urls = false) {
    const events = (await list(eventTable(task.taskId))).sort(
      (a, b) => (a.sequence ?? 0) - (b.sequence ?? 0) || a.at.localeCompare(b.at) || a.id.localeCompare(b.id),
    );
    const evidence = [],
      seen = new Set();
    for (const e of events)
      if (e.kind === 'evidence' && !seen.has(e.operationId)) {
        seen.add(e.operationId);
        evidence.push({
          id: e.id,
          name: e.name,
          contentType: e.contentType,
          size: e.size,
          at: e.at,
          path: e.path,
        });
      }
    let signed = [];
    if (urls && evidence.length)
      signed = await storage.url(evidence.map((e) => e.path));
    // Old completed receipts represent delivery, not administrative approval.
    // A review always names its submission; concurrent decisions cannot approve
    // a later delivery or erase a previously accepted review.
    let status = events.length ? 'en_progreso' : 'pendiente';
    let submission = null, review = null, percentage = 0;
    const decisions = new Set();
    for (const e of events) {
      if (e.kind === 'progress' && Number.isInteger(e.percentage)) percentage = e.percentage;
      if (['submitted', 'completed'].includes(e.kind) && status !== 'completado' && status !== 'en_revision') {
        submission = e;
        review = null;
        status = 'en_revision';
        percentage = 100;
      }
      if (['approved', 'changes_requested'].includes(e.kind) &&
          submission && e.submissionId === submission.operationId &&
          !decisions.has(e.submissionId)) {
        decisions.add(e.submissionId);
        review = e;
        status = e.kind === 'approved' ? 'completado' : 'cambios_solicitados';
        if (status === 'cambios_solicitados') percentage = Math.min(percentage, 90);
      }
    }
    return {
      ...task,
      workKind: task.workKind || 'dia',
      status,
      percentage,
      submissionId: submission?.operationId || null,
      submittedAt: submission?.at || null,
      completedAt: status === 'completado' ? review?.at : null,
      reviewComment: review?.comment || '',
      evidenceCount: evidence.length,
      evidence: urls
        ? evidence.map(({ path, ...e }) => ({
            ...e,
            url: signed.find((s) => s.path === path)?.url || null,
          }))
        : [],
      history: urls
        ? events
            .filter((e) => e.kind !== 'evidence')
            .map(({ id, kind, comment, at, actorName, percentage }) => ({
              id,
              kind,
              comment,
              at,
              actorName,
              percentage,
            }))
        : [],
    };
  }
  async function profile(uid, token) {
    check(
      typeof uid === 'string' &&
        uid.length > 0 &&
        uid.length <= 128 &&
        !uid.includes('/'),
      'Selecciona una cuenta válida.',
    );
    const r = await fetcher(
      `${ROOT}/usuarios/${encodeURIComponent(uid)}?mask.fieldPaths=nombre&mask.fieldPaths=rol&mask.fieldPaths=activo`,
      {
        headers: { Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(12000),
      },
    );
    check(
      r.ok,
      'No se pudo validar la persona asignada.',
      r.status === 429 ? 429 : 403,
    );
    const fields = (await r.json()).fields || {};
    check(
      ROLES.includes(fields.rol?.stringValue) &&
        fields.activo?.booleanValue !== false,
      'La cuenta asignada no está activa.',
      409,
    );
    return String(fields.nombre?.stringValue || 'Integrante').slice(0, 160);
  }
  async function addEvent(task, record) {
    const [id] = await db.add(eventTable(task.taskId), [record]);
    check(
      id,
      'No se confirmó el guardado. Actualiza la tarea antes de reintentar.',
      503,
    );
    return id;
  }
  return async function daily(action, b, u, { token } = {}) {
    check(
      u && ROLES.includes(u.role),
      'Inicia sesión con un perfil activo.',
      403,
    );
    const day = date(b.day);
    const operational = day.length === 6;
    async function response(task, event, actor = u) {
      const current = await state(task, true);
      const notice = await notify({ task: current, event, user: actor, token });
      return { saved: true, task: current, ...notice };
    }
    if (action === 'daily-create') {
      check(
        assigner(u),
        'Solo administradores y maestros asignan tareas del día.',
        403,
      );
      const workKind = b.workKind || 'dia';
      check((operational ? ['instalacion', 'envio'] : ['dia', 'extra']).includes(workKind),
        'Elige el tipo de trabajo y su fecha.');
      const title = text(b.title, 150, 3),
        details = text(b.details || '', 2000, 0),
        operationId = text(b.operationId, 100);
      const userName = await profile(b.userId, token);
      const taskId = hash(`${u.uid}\n${day}\n${operationId}`);
      const existing = await tasks(day),
        old = existing.find((t) => t.taskId === taskId);
      if (old) {
        check(
          old.userId === b.userId &&
            old.title === title &&
            old.details === details && (old.workKind || 'dia') === workKind,
          'Ese intento ya guardó otra tarea. Abre una nueva asignación.',
          409,
        );
        return response(old, { kind: 'assigned', operationId });
      }
      check(
        existing.length < 80,
        'Este día ya tiene 80 tareas. Usa otra fecha o revisa las asignaciones.',
        409,
      );
      const dueAt = b.dueAt == null ? null : text(b.dueAt, 40);
      check(
        dueAt === null || Number.isFinite(Date.parse(dueAt)),
        'La fecha de entrega no es válida.',
      );
      const record = {
        taskId,
        day,
        title,
        details,
        workKind,
        userId: b.userId,
        userName,
        createdBy: u.uid,
        createdByName: u.name,
        createdAt: clock().toISOString(),
        dueAt,
      };
      const [id] = await db.add(taskTable(day), [record]);
      check(
        id,
        'No se confirmó la asignación. Conserva el formulario y vuelve a intentar.',
        503,
      );
      return response(await getTask(day, taskId, u), { kind: 'assigned', operationId });
    }
    if (action === 'daily-list') {
      const visible = (await tasks(day)).filter((t) => canRead(t, u));
      const items = [];
      for (const t of visible) items.push(await state(t));
      return { items, day };
    }
    const task = await getTask(day, b.taskId, u);
    if (action === 'daily-read') return { task: await state(task, true) };
    check(
      ['daily-evidence', 'daily-progress', 'daily-complete', 'daily-review'].includes(action),
      'Acción no reconocida.',
      404,
    );
    check(
      action === 'daily-review'
        ? assigner(u) && (u.role === 'admin' || task.createdBy === u.uid)
        : task.userId === u.uid || (operational && u.role === 'admin' && action !== 'daily-complete'),
      'La evidencia y la entrega las registra la persona asignada.',
      403,
    );
    const rows = await list(eventTable(task.taskId)),
      current = await state(task);
    const operationId = text(b.operationId, 100);
    const previous = rows.find((e) => e.operationId === operationId);
    if (previous) {
      check(previous.actorId === u.uid && previous.action === action,
        'Este intento pertenece a otra operación.', 409);
      return response(task, previous);
    }
    check(current.status !== 'completado', 'La tarea ya está terminada.', 409);
    check(
      rows.length < 80,
      'Esta tarea tiene demasiados movimientos. Consulta a quien la asignó.',
      409,
    );
    const common = {
      operationId,
      action,
      sequence: rows.length + 1,
      actorId: u.uid,
      actorName: u.name,
      at: clock().toISOString(),
    };
    if (action === 'daily-review') {
      check(current.status === 'en_revision' && b.submissionId === current.submissionId,
        'La entrega cambió. Actualiza antes de revisarla.', 409);
      check(['approve', 'changes'].includes(b.decision), 'Selecciona una revisión válida.');
      const event = { ...common, submissionId: current.submissionId,
        kind: b.decision === 'approve' ? 'approved' : 'changes_requested',
        comment: text(b.comment || (b.decision === 'approve' ? 'Entrega aprobada.' : ''), 2000) };
      await addEvent(task, event);
      return response(task, event);
    }
    check(current.status !== 'en_revision', 'Tu entrega está en revisión. Espera la respuesta.', 409);
    if (action === 'daily-complete') {
      const comment = text(b.comment || '', 2000, 0);
      check(current.evidenceCount > 0 || comment.length >= 5,
        'Adjunta una foto o escribe qué terminaste.', 409);
      const event = { ...common, kind: 'submitted', comment: comment || 'Trabajo terminado; evidencias adjuntas.' };
      await addEvent(task, event);
      return response(task, event);
    }
    if (action === 'daily-progress') {
      const percentage = b.percentage ?? current.percentage;
      check(Number.isInteger(percentage) && percentage >= 0 && percentage <= 100,
        'El avance debe estar entre 0 y 100 %.');
      const event = { ...common, kind: 'progress', percentage,
        comment: text(b.comment, 2000) };
      await addEvent(task, event);
      return response(task, event);
    }
    check(
      typeof b.base64 === 'string' &&
        b.base64.length <= 2800000 &&
        /^[A-Za-z0-9+/]+={0,2}$/.test(b.base64),
      'Adjunta una foto o PDF de hasta 2 MB.',
    );
    const bytes = Buffer.from(b.base64, 'base64');
    check(
      bytes.length > 0 && bytes.length <= 2 * 1024 * 1024,
      'El archivo debe pesar como máximo 2 MB.',
    );
    let extension, contentType;
    if (bytes.subarray(0, 5).toString() === '%PDF-') {
      extension = 'pdf';
      contentType = 'application/pdf';
    } else if (
      bytes.length > 8 &&
      bytes
        .subarray(0, 8)
        .equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
    ) {
      extension = 'png';
      contentType = 'image/png';
    } else if (
      bytes.length > 3 &&
      bytes[0] === 255 &&
      bytes[1] === 216 &&
      bytes[2] === 255
    ) {
      extension = 'jpg';
      contentType = 'image/jpeg';
    } else if (
      bytes.subarray(0, 4).toString() === 'RIFF' &&
      bytes.subarray(8, 12).toString() === 'WEBP'
    ) {
      extension = 'webp';
      contentType = 'image/webp';
    }
    check(contentType, 'Usa una imagen JPG, PNG, WebP o un PDF.');
    const name = text(b.name, 160),
      path = `daily-evidence/${task.taskId}/${hash(u.uid)}/${randomUUID()}.${extension}`;
    const [uploaded] = await storage.write([
      { path, content: b.base64, contentType },
    ]);
    check(
      uploaded,
      'No se pudo subir la evidencia. La tarea sigue pendiente.',
      503,
    );
    const event = {
      ...common,
      kind: 'evidence',
      name,
      path,
      contentType,
      size: bytes.length,
    };
    await addEvent(task, event);
    return response(task, event);
  };
}
