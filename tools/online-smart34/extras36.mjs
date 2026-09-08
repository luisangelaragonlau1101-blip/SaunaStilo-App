// Extra work reports and shortages are separate records, not assigned project tasks.
export function createExtraService({db, Fault}) {
  const guard = (ok, message, status = 400) => { if (!ok) throw new Fault(message, status); };
  const text = (v, max, min = 1) => {
    guard(typeof v === 'string' && v.trim().length >= min && v.trim().length <= max, 'Revisa el texto del reporte.');
    return v.trim();
  };
  function day(value) {
    const d = new Date(String(value) + 'T12:00:00Z');
    const today = new Date(Date.now() - 6 * 3600000).toISOString().slice(0, 10);
    guard(typeof value === 'string' && /^20\d{2}-\d{2}-\d{2}$/.test(value) && Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === value && value <= today, 'El reporte debe corresponder a una fecha real, no futura.');
    return value;
  }
  const table = (uid, date) => `sauna36-extras:${uid}:${date}`;
  async function rows(uid, date) {
    const r = await db.list(table(uid, date), {limit: 200});
    guard(!r.nextToken, 'Este día excede la capacidad de consulta. No se ocultó ni borró el historial.', 409);
    return r.items.sort((a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id));
  }
  function replay(log) {
    const map = new Map(), seen = new Set();
    for (const r of log) {
      const key = r.actorId + ':' + r.operationId;
      if (seen.has(key)) continue;
      seen.add(key);
      if (r.kind === 'report') map.set(r.id, {...r, status: 'pendiente_revision'});
      else if (r.kind === 'review' && map.has(r.reportId)) Object.assign(map.get(r.reportId), {status: r.accepted ? 'revisado' : 'requiere_aclaracion', review: r.comment, reviewer: r.actorName, reviewedAt: r.at});
    }
    return [...map.values()].reverse();
  }
  async function add(uid, date, log, u, b, data) {
    const op = text(b.operationId, 100);
    const prior = log.find(e => e.operationId === op && e.actorId === u.uid);
    if (prior) return prior.id;
    guard(log.length < 180, 'El historial de este día está lleno. Administración debe ampliar su capacidad.', 409);
    const at = new Date(Math.max(Date.now(), ...log.map(e => Date.parse(e.at) + 1))).toISOString();
    const [id] = await db.add(table(uid, date), [{...data, at, date, actorId: u.uid, actorName: u.name, operationId: op}]);
    guard(id, 'No se confirmó el reporte. Consulta el historial antes de reintentar.', 503);
    return id;
  }
  return async function extra(action, b, u) {
    const date = day(b.date);
    if (action === 'extra-inbox') {
      guard(u.role === 'admin', 'Solo Administración puede revisar reportes del equipo.', 403);
      guard(Array.isArray(b.userIds) && b.userIds.length > 0 && b.userIds.length <= 8 && b.userIds.every(id => typeof id === 'string' && /^[^/]{1,128}$/.test(id)), 'Consulta hasta ocho personas por página.');
      const items = [];
      for (const uid of [...new Set(b.userIds)]) for (const report of replay(await rows(uid, date))) items.push({...report, userId: uid});
      return {items};
    }
    const uid = b.userId || u.uid;
    guard(typeof uid === 'string' && /^[^/]{1,128}$/.test(uid), 'Cuenta inválida.');
    guard(uid === u.uid || u.role === 'admin', 'No puedes consultar reportes ajenos.', 403);
    const log = await rows(uid, date);
    if (action === 'extra-list') return {items: replay(log), date};
    if (action === 'extra-create') {
      guard(uid === u.uid, 'Cada persona registra únicamente lo que ella realizó.', 403);
      guard(b.performed === true, 'Confirma que describes trabajo ya realizado o un faltante detectado.');
      guard(['extra', 'faltante'].includes(b.category), 'Selecciona trabajo extra o faltante.');
      const title = text(b.title, 160), description = text(b.description, 3000, 8);
      const minutes = b.minutes ?? 0;
      guard(Number.isInteger(minutes) && minutes >= 0 && minutes <= 1440, 'Usa minutos de 0 a 1440.');
      const id = await add(uid, date, log, u, b, {kind: 'report', category: b.category, title, description, minutes});
      return {id, saved: true, assignedTaskCreated: false};
    }
    if (action === 'extra-review') {
      guard(u.role === 'admin', 'Solo Administración puede revisar este reporte.', 403);
      const id = text(b.id, 100);
      guard(replay(log).some(r => r.id === id), 'Reporte no encontrado.', 404);
      guard(typeof b.accepted === 'boolean', 'Indica el resultado de la revisión.');
      await add(uid, date, log, u, b, {kind: 'review', reportId: id, accepted: b.accepted, comment: text(b.comment, 1000, 3)});
      return {saved: true};
    }
    throw new Fault('Acción no reconocida.', 404);
  };
}
