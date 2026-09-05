/* The click listener must precede Firebase imports. */
const APP_BASE = new URL('./', self.location.href);
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  const raw = event.notification.data || {};
  const data = raw.FCM_MSG ? (raw.FCM_MSG.data || {}) : raw;
  const target = new URL(APP_BASE.href);
  if (data.notificationId) target.searchParams.set('notification', String(data.notificationId).slice(0, 180));
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      const current = new URL(client.url);
      if (current.origin === APP_BASE.origin && current.pathname.startsWith(APP_BASE.pathname)) {
        // Navigate in this app's origin, never an arbitrary URL from a payload.
        try {
          const navigated = await client.navigate(target.href);
          if (navigated) return await navigated.focus();
        } catch (_) { /* Try opening the app if this client closed. */ }
      }
    }
    return self.clients.openWindow(target.href);
  })());
});
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey: 'AIzaSyCqvb1kOvxvPTZzCZLQx6aZgEBnC-AZnYE',
  authDomain: 'saunastiloapp-17e15.firebaseapp.com',
  projectId: 'saunastiloapp-17e15',
  storageBucket: 'saunastiloapp-17e15.firebasestorage.app',
  messagingSenderId: '1083212885362',
  appId: '1:1083212885362:web:0b99846f25c4d5c005c1eb'
});
firebase.messaging().onBackgroundMessage(async (payload) => {
  // Firebase already displays notification payloads: do not duplicate them.
  if (payload.notification) return;
  const data = payload.data || {};
  const call = data.esLlamada === 'true';
  const expired = call && Number(data.expiresAt || 0) > 0 && Number(data.expiresAt) < Date.now();
  return self.registration.showNotification(
    expired ? 'Llamada recibida · Sauna Stilo' : (data.title || data.titulo || 'Sauna Stilo'),
    {
      body: expired ? 'Revisa el chat para devolver la llamada.' : (data.body || data.mensaje || 'Tienes un nuevo aviso.'),
      icon: new URL('icons/Icon-192.png', APP_BASE).href,
      badge: new URL('icons/Icon-192.png', APP_BASE).href,
      tag: String(data.notificationId || payload.messageId || 'sauna-aviso'),
      requireInteraction: call && !expired,
      silent: false,
      data: { notificationId: data.notificationId || '', type: data.type || '' }
    }
  );
});
