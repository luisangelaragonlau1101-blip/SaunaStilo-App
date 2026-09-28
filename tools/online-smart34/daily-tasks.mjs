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
      typeof value === 'string' && /^20\d{6}$/.test(value),
      'Selecciona el día de la tarea.',
    );
    const d = new Date(
      `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6)}T12:00:00Z`,
    );
    check(
      Number.isFinite(d.getTime()) &&
        d.toISOString().slice(0, 10).replaceAll('-', '') === value,
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
      (a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id),
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
    const completed = events.find((e) => e.kind === 'completed');
    return {
      ...task,
      status: completed
        ? 'completado'
        : events.length
          ? 'en_progreso'
          : 'pendiente',
      completedAt: completed?.at || null,
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
            .map(({ id, kind, comment, at, actorName }) => ({
              id,
              kind,
              comment,
              at,
              actorName,
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
    return state(task, true);
  }
  return async function daily(action, b, u, { token } = {}) {
    check(
      u && ROLES.includes(u.role),
      'Inicia sesión con un perfil activo.',
      403,
    );
    const day = date(b.day);
    if (action === 'daily-create') {
      check(
        assigner(u),
        'Solo administradores y maestros asignan tareas del día.',
        403,
      );
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
            old.details === details,
          'Ese intento ya guardó otra tarea. Abre una nueva asignación.',
          409,
        );
        return { saved: true, task: await state(old, true) };
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
      return {
        saved: true,
        task: await state(await getTask(day, taskId, u), true),
      };
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
      ['daily-evidence', 'daily-progress', 'daily-complete'].includes(action),
      'Acción no reconocida.',
      404,
    );
    check(
      task.userId === u.uid,
      'La evidencia y la entrega las registra la persona asignada.',
      403,
    );
    const rows = await list(eventTable(task.taskId)),
      current = await state(task);
    const operationId = text(b.operationId, 100);
    if (rows.some((e) => e.operationId === operationId))
      return { saved: true, task: await state(task, true) };
    check(current.status !== 'completado', 'La tarea ya está terminada.', 409);
    check(
      rows.length < 80,
      'Esta tarea tiene demasiados movimientos. Consulta a quien la asignó.',
      409,
    );
    const common = {
      operationId,
      actorId: u.uid,
      actorName: u.name,
      at: clock().toISOString(),
    };
    if (action === 'daily-complete') {
      check(
        current.evidenceCount > 0,
        'Adjunta por lo menos una evidencia antes de terminar.',
        409,
      );
      return {
        saved: true,
        task: await addEvent(task, {
          ...common,
          kind: 'completed',
          comment: 'Tarea terminada con evidencia.',
        }),
      };
    }
    if (action === 'daily-progress')
      return {
        saved: true,
        task: await addEvent(task, {
          ...common,
          kind: 'progress',
          comment: text(b.comment, 2000),
        }),
      };
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
    return {
      saved: true,
      task: await addEvent(task, {
        ...common,
        kind: 'evidence',
        name,
        path,
        contentType,
        size: bytes.length,
      }),
    };
  };
}
