// Notification acceptance by FCM is not proof of display or sound on a phone.
function buildPushPayload({ notificationId, data, now = Date.now() }) {
  const type = String(data.tipo || 'general');
  const isAlarm = type === 'alarma_admin';
  const created = data.fecha && typeof data.fecha.toMillis === 'function' ? data.fecha.toMillis() : now;
  const isCall = data.esLlamada === true;
  const liveCall = isCall && now - created < 60000;
  const ttl = liveCall ? Math.max(1, Math.ceil((created + 60000 - now) / 1000)) : (isAlarm ? 900 : 86400);
  const title = String(data.titulo || 'Sauna Stilo').slice(0, 180);
  const body = isCall && !liveCall ? 'Recibiste una invitación de llamada. Revisa tu chat.' : String(data.mensaje || 'Tienes un nuevo aviso.').slice(0, 500);
  const extra = {};
  for (const [target, source] of Object.entries({ route: 'ruta', projectId: 'proyectoId', conversationId: 'conversacionId' })) {
    if (data[source]) extra[target] = String(data[source]).slice(0, 180);
  }
  return {
    notification: { title, body },
    data: { notificationId, type, esLlamada: String(liveCall), expiresAt: String(isCall ? created + 60000 : 0), ...extra },
    android: {
      priority: 'high', ttl: ttl * 1000,
      notification: {
        channelId: isAlarm ? 'sauna_alarmas_urgentes' : 'sauna_alertas',
        sound: 'default', priority: liveCall || isAlarm ? 'max' : 'high',
        tag: notificationId,
        sticky: liveCall || isAlarm,
      },
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert', 'apns-expiration': String(Math.floor(now / 1000) + ttl) },
      payload: { aps: { sound: 'default' } },
    },
    webpush: {
      headers: { Urgency: 'high', TTL: String(ttl) },
      notification: {
        icon: './icons/Icon-192.png', badge: './icons/Icon-192.png', tag: notificationId,
        requireInteraction: liveCall || isAlarm, renotify: liveCall || isAlarm, silent: false,
        data: { notificationId, type },
      },
      // No external destination: the installed service worker opens its own app origin.
    },
  };
}
module.exports = { buildPushPayload };
