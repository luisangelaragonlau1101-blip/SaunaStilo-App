const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

const USERS_COLLECTION = 'usuarios';
const MAX_TOKENS_PER_SEND = 500;
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');

exports.saunaAssistant = onCall(
  {
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        'unauthenticated',
        'Debes iniciar sesión para usar el asistente.',
      );
    }

    const question = String(request.data && request.data.pregunta || '').trim();
    if (!question || question.length > 2500) {
      throw new HttpsError(
        'invalid-argument',
        'La pregunta debe contener entre 1 y 2500 caracteres.',
      );
    }

    const db = getFirestore();
    const user = await db.collection(USERS_COLLECTION).doc(request.auth.uid).get();
    if (!user.exists) {
      throw new HttpsError('permission-denied', 'El perfil no existe.');
    }
    const userData = user.data() || {};
    const role = String(userData.rol || 'trabajador').trim().toLowerCase();
    const isAdmin = role === 'admin';
    const context = await buildAssistantContext({
      db,
      uid: request.auth.uid,
      role,
      isAdmin,
    });
    const history = sanitizeHistory(request.data && request.data.historial);
    const images = sanitizeImageUrls(request.data && request.data.imagenes);
    const scope = isAdmin
      ? 'administrador: proyectos, clientes, cotizaciones, tareas y almacén'
      : role === 'almacenista'
        ? 'almacenista: inventario, solicitudes y sus tareas; sin clientes, cotizaciones ni proyectos administrativos'
        : 'trabajador: únicamente sus tareas, evidencias, solicitudes y herramientas; sin clientes, cotizaciones ni proyectos administrativos';

    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY.value()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || 'gpt-5.6',
        store: false,
        max_output_tokens: 900,
        instructions: [
          'Eres Sauna IA, asistente operativo de Sauna Stilo. Responde siempre en español claro y directo.',
          'Usa los datos empresariales suministrados como fuente factual. Si un dato no aparece, dilo y no lo inventes.',
          'Puedes crear resúmenes, estadísticas, planes, listas, borradores y recomendaciones.',
          `Alcance autorizado del usuario: ${scope}.`,
          'Nunca infieras, solicites ni reveles información reservada fuera de ese alcance.',
          'Para administración, señala prioridades, bloqueos, fechas y estados cuando sean relevantes.',
          `DATOS AUTORIZADOS ACTUALES:\n${JSON.stringify(context)}`,
        ].join('\n'),
        input: [
          ...history.map((item) => ({
            role: item.rol === 'asistente' ? 'assistant' : 'user',
            content: item.texto,
          })),
          {
            role: 'user',
            content: images.length
              ? [
                  { type: 'input_text', text: question },
                  ...images.map((imageUrl) => ({
                    type: 'input_image',
                    image_url: imageUrl,
                    detail: 'auto',
                  })),
                ]
              : question,
          },
        ],
      }),
    });

    if (!response.ok) {
      console.error('[assistant] OpenAI error', { status: response.status });
      throw new HttpsError(
        'unavailable',
        'El motor inteligente no está disponible en este momento.',
      );
    }
    const payload = await response.json();
    const answer = extractResponseText(payload);
    if (!answer) {
      throw new HttpsError(
        'internal',
        'El asistente no produjo una respuesta válida.',
      );
    }
    return { respuesta: answer, alcance: scope };
  },
);

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
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
          },
          fcmOptions: {
            link: `https://sauna-stilo-app-web.vercel.app/?notification=${notificationId}`,
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

exports.reminderEntrada = onSchedule(
  { schedule: '0 9 * * 1-6', timeZone: 'America/Mexico_City' },
  async () => createWorkdayReminders({
    type: 'entrada',
    title: '¡Buenos días! 👋',
    body: 'Registra tu entrada en Sauna Stilo para comenzar tu jornada.',
  }),
);

exports.reminderComida = onSchedule(
  { schedule: '0 15 * * 1-6', timeZone: 'America/Mexico_City' },
  async () => createWorkdayReminders({
    type: 'comida',
    title: 'Ey, ya es tu hora de comida 🍽️',
    body: 'Registra tu salida a comer. Al volver, registra también tu regreso.',
  }),
);

exports.reminderSalida = onSchedule(
  { schedule: '0 19 * * 1-6', timeZone: 'America/Mexico_City' },
  async () => createWorkdayReminders({
    type: 'salida',
    title: 'Tu jornada terminó ✅',
    body: 'Antes de retirarte, recuerda registrar tu salida.',
  }),
);

exports.reminderAusencias = onSchedule(
  { schedule: '30 9 * * 1-6', timeZone: 'America/Mexico_City' },
  async () => {
    const db = getFirestore();
    const dateKey = mexicoDateKey();
    const users = await db.collection(USERS_COLLECTION).get();
    await Promise.all(users.docs.map(async (user) => {
      const data = user.data() || {};
      if (String(data.rol || '').toLowerCase() === 'admin') return;
      const attendance = await db
        .collection('asistencias')
        .doc(`${user.id}_${dateKey}`)
        .get();
      if (attendance.exists && attendance.data().horaEntrada) return;
      await db.collection('notificaciones').doc(`ausencia_${dateKey}_${user.id}`).set({
        titulo: 'Te extrañamos en Sauna Stilo',
        mensaje: 'Aún no aparece tu entrada de hoy. Regístrala o avisa a administración si necesitas apoyo.',
        tipo: 'asistencia_ausente',
        destinatarioId: user.id,
        rolesDestinatarios: [],
        leidosPor: [],
        fecha: FieldValue.serverTimestamp(),
      }, { merge: true });
    }));
  },
);

async function createWorkdayReminders({ type, title, body }) {
  const db = getFirestore();
  const dateKey = mexicoDateKey();
  const users = await db.collection(USERS_COLLECTION).get();
  await Promise.all(users.docs.map((user) => {
    const data = user.data() || {};
    if (String(data.rol || '').toLowerCase() === 'admin') return null;
    return db.collection('notificaciones').doc(`jornada_${type}_${dateKey}_${user.id}`).set({
      titulo: title,
      mensaje: body,
      tipo: `asistencia_${type}`,
      destinatarioId: user.id,
      rolesDestinatarios: [],
      leidosPor: [],
      fecha: FieldValue.serverTimestamp(),
    }, { merge: true });
  }));
}

function mexicoDateKey() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Mexico_City',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}${value.month}${value.day}`;
}

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

async function buildAssistantContext({ db, uid, role, isAdmin }) {
  const activityQuery = isAdmin
    ? db.collection('actividades').limit(120)
    : db
        .collection('actividades')
        .where('asignadoATrabajadorId', '==', uid)
        .limit(80);
  const requestQuery = isAdmin || role === 'almacenista'
    ? db.collection('solicitudes_herramientas').limit(100)
    : db
        .collection('solicitudes_herramientas')
        .where('trabajadorId', '==', uid)
        .limit(60);

  const [activities, requests, inventory, staff] = await Promise.all([
    activityQuery.get(),
    requestQuery.get(),
    db.collection('insumos_inventario').limit(160).get(),
    db.collection(USERS_COLLECTION).limit(200).get(),
  ]);

  const context = {
    rol: role,
    tareas: activities.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        titulo: clean(data.titulo),
        descripcion: clean(data.descripcion, 280),
        estatus: clean(data.estatus),
        trabajadorId: isAdmin ? clean(data.asignadoATrabajadorId) : uid,
        fechaAsignada: dateValue(data.fechaAsignada || data.fechaInicio),
        fechaLimite: dateValue(data.fechaTermino),
        evidencias: safeNumber(data.evidenciasCount || data.cantidadEvidencias),
        requiereEvidencia: data.requiereEvidencia !== false,
      };
    }),
    solicitudesHerramientas: requests.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        articulo: clean(data.nombreInsumo),
        cantidad: safeNumber(data.cantidad),
        estatus: clean(data.estatus),
        trabajador: isAdmin || role === 'almacenista'
          ? clean(data.trabajadorNombre)
          : undefined,
        fecha: dateValue(data.fechaSolicitud),
      };
    }),
    inventario: inventory.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        nombre: clean(data.nombre),
        disponible: safeNumber(
          data.cantidadDisponible !== undefined
            ? data.cantidadDisponible
            : data.cantidad_disponible,
        ),
        unidad: clean(data.unidadMedida || data.unidad_medida),
      };
    }),
    equipo: staff.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        nombre: clean(data.nombre),
        rol: clean(data.rol),
        cumpleanos: dateValue(data.cumpleanos),
      };
    }),
  };

  if (!isAdmin) return context;

  const [projects, clients, quotes] = await Promise.all([
    db.collection('proyectos').limit(120).get(),
    db.collection('clientes').limit(150).get(),
    db.collection('seguimiento_cotizaciones').limit(120).get(),
  ]);
  context.proyectos = projects.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      titulo: clean(data.titulo),
      estatus: clean(data.estatus),
      clienteId: clean(data.id_cliente),
      descripcion: clean(data.descripcion, 320),
      medidas: clean(data.medidas),
      fechaInicio: dateValue(data.fecha_inicio),
      fechaEntrega: dateValue(data.fecha_entrega),
      encargados: Array.isArray(data.encargados)
        ? data.encargados.map((value) => clean(value)).filter(Boolean).slice(0, 20)
        : [],
    };
  });
  context.clientes = clients.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      nombre: clean(data.nombre),
      telefono: clean(data.telefono),
      direccion: clean(data.direccion, 260),
      fechaRegistro: dateValue(data.fecha_registro),
    };
  });
  context.cotizaciones = quotes.docs.map((doc) => {
    const data = doc.data();
    const client = data.datos_cliente || {};
    const project = data.datos_proyecto || {};
    return {
      id: doc.id,
      estatus: clean(data.estatus_cotizacion),
      monto: safeNumber(data.monto_cotizado),
      fecha: dateValue(data.fecha_cotizacion),
      clienteId: clean(data.id_cliente),
      cliente: clean(client.nombre),
      telefono: clean(client.telefono),
      proyecto: clean(project.titulo),
      descripcion: clean(project.descripcion, 280),
      administrador: clean(data.admin_encargado),
    };
  });
  return context;
}

function sanitizeHistory(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.slice(-10).map((item) => ({
    rol: item && item.rol === 'asistente' ? 'asistente' : 'usuario',
    texto: clean(item && item.texto, 1200),
  })).filter((item) => item.texto);
}

function sanitizeImageUrls(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, 8).map((value) => {
    try {
      const url = new URL(String(value || ''));
      const allowedHosts = new Set([
        'firebasestorage.googleapis.com',
        'storage.googleapis.com',
      ]);
      return url.protocol === 'https:' && allowedHosts.has(url.hostname)
        ? url.toString()
        : '';
    } catch (_) {
      return '';
    }
  }).filter(Boolean);
}

function extractResponseText(payload) {
  const texts = [];
  const output = Array.isArray(payload && payload.output) ? payload.output : [];
  for (const item of output) {
    if (!item || item.type !== 'message' || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (content && content.type === 'output_text' && content.text) {
        texts.push(String(content.text).trim());
      }
    }
  }
  return texts.filter(Boolean).join('\n').trim();
}

function clean(value, maxLength = 180) {
  if (value === null || value === undefined) return '';
  return String(value).replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function safeNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function dateValue(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return clean(value);
}
