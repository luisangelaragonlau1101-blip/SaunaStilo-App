import { createHash } from 'node:crypto';

const ROOT = 'https://firestore.googleapis.com/v1/projects/saunastiloapp-17e15/databases/(default)/documents';
const string = (v) => ({ stringValue: String(v) });
const array = (v) => ({ arrayValue: { values: v.map(string) } });

// Business records are committed first. A notice failure is returned explicitly
// and must never roll back a delivery, attendance receipt or approval.
export function createWorkNotifier({ fetcher = fetch, clock = () => new Date() } = {}) {
  return async function notify({ key, title, message, type, recipient, roles = [], fields = {}, user, token }) {
    const id = `work_${createHash('sha256').update(key).digest('hex')}`;
    try {
      const result = await fetcher(`${ROOT}/notificaciones?documentId=${id}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(8000),
        body: JSON.stringify({ fields: {
          titulo: string(title), mensaje: string(message), tipo: string(type),
          destinatarioId: string(recipient || ''), rolesDestinatarios: array(roles),
          leidosPor: array([]), creadoPor: string(user.uid),
          fecha: { timestampValue: clock().toISOString() },
          ...Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, string(v)])),
        } }),
      });
      // CREATE's conflict means this exact deterministic notice already exists.
      if (result.ok || result.status === 409) return { notificationSaved: true };
    } catch (_) { /* Keep the durable operation and disclose the separate failure. */ }
    return { notificationSaved: false,
      notificationWarning: 'El cambio quedó guardado, pero no se confirmó el aviso. Actualiza la tarea y vuelve a intentar el aviso.' };
  };
}

export function taskNotice(task, event, user) {
  const labels = { assigned: 'Nueva asignación', evidence: 'Nueva evidencia', progress: 'Avance registrado',
    submitted: 'Entrega pendiente de aprobación', completed: 'Entrega pendiente de aprobación',
    approved: 'Tarea aprobada', changes_requested: 'Se solicitaron cambios' };
  const review = ['submitted', 'completed', 'progress', 'evidence'].includes(event.kind);
  return {
    key: `task:${task.taskId}:${event.operationId}`,
    title: labels[event.kind] || 'Tarea actualizada',
    message: `${user.name}: ${task.title}`,
    type: 'tarea', recipient: review ? task.createdBy : task.userId,
    roles: review ? ['admin'] : [],
    fields: { dailyTaskId: task.taskId, dailyTaskDay: task.day },
  };
}
