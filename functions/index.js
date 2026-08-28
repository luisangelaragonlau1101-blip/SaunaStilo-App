const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

const USERS_COLLECTION = 'usuarios';
const MAX_TOKENS_PER_SEND = 500;

exports.sendSaunaStiloNotification = onDocumentCreated(
  'notificaciones/{notificationId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notificationId = event.params.notificationId;
    const data = snapshot.data();
    const title = String(data.titulo || 'Sauna Stilo').trim();
    const body = String(data.mensaje || 'Tienes un nuevo aviso.').trim();
    const targetUserId = String(data.destinatarioId || '').trim();
    const targetRoles = Array.isArray(data.rolesDestinatarios)
      ? data.rolesDestinatarios.map((role) => String(role).trim()).filter(Boolean)
      : [];

    const users = await resolveRecipients({ targetUserId, targetRoles });
    const tokenOwners = new Map();
    for (const user of users) {
      const tokens = Array.isArray(user.data().fcmTokens)
        ? user.data().fcmTokens.filter((token) => typeof token === 'string' && token)
        : [];
      for (const token of tokens) {
        if (!tokenOwners.has(token)) tokenOwners.set(token, new Set());
        tokenOwners.get(token).add(user.id);
      }
    }

    const tokens = [...tokenOwners.keys()];
    if (!tokens.length) {
      console.log('[push] Aviso sin dispositivos registrados', { notificationId });
      return;
    }

    const invalidTokens = new Set();
    for (let start = 0; start < tokens.length; start += MAX_TOKENS_PER_SEND) {
      const batchTokens = tokens.slice(start, start + MAX_TOKENS_PER_SEND);
      const response = await getMessaging().sendEachForMulticast({
        tokens: batchTokens,
        notification: { title, body },
        data: {
          notificationId,
          type: String(data.tipo || 'general'),
        },
        android: {
          priority: 'high',
          ttl: 24 * 60 * 60 * 1000,
          notification: {
            channelId: 'sauna_alertas',
            sound: 'default',
            priority: 'high',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default', badge: 1 } },
        },
        webpush: {
          notification: {
            icon: '/SaunaStilo-App/icons/Icon-192.png',
            badge: '/SaunaStilo-App/icons/Icon-192.png',
          },
          fcmOptions: {
            link: `https://luisangelaragonlau1101-blip.github.io/SaunaStilo-App/?notification=${notificationId}`,
          },
        },
      });

      response.responses.forEach((item, index) => {
        const code = item.error && item.error.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          invalidTokens.add(batchTokens[index]);
        }
      });
      console.log('[push] Lote enviado', {
        notificationId,
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
    }

    await removeInvalidTokens({ invalidTokens, tokenOwners });
  },
);

async function resolveRecipients({ targetUserId, targetRoles }) {
  const db = getFirestore();
  const users = new Map();
  const forEveryone =
    targetUserId === 'todos' || targetRoles.includes('todos');

  if (forEveryone) {
    const snapshot = await db.collection(USERS_COLLECTION).get();
    snapshot.docs.forEach((doc) => users.set(doc.id, doc));
    return [...users.values()];
  }

  if (targetUserId) {
    const user = await db.collection(USERS_COLLECTION).doc(targetUserId).get();
    if (user.exists) users.set(user.id, user);
  }

  for (const role of new Set(targetRoles)) {
    const snapshot = await db
      .collection(USERS_COLLECTION)
      .where('rol', '==', role)
      .get();
    snapshot.docs.forEach((doc) => users.set(doc.id, doc));
  }

  return [...users.values()];
}

async function removeInvalidTokens({ invalidTokens, tokenOwners }) {
  if (!invalidTokens.size) return;
  const db = getFirestore();
  const removalsByUser = new Map();
  for (const token of invalidTokens) {
    for (const userId of tokenOwners.get(token) || []) {
      if (!removalsByUser.has(userId)) removalsByUser.set(userId, []);
      removalsByUser.get(userId).push(token);
    }
  }
  await Promise.all(
    [...removalsByUser.entries()].map(([userId, tokens]) =>
      db.collection(USERS_COLLECTION).doc(userId).update({
        fcmTokens: FieldValue.arrayRemove(...tokens),
      }),
    ),
  );
}
