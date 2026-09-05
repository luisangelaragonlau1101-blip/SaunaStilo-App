const { FieldValue } = require('firebase-admin/firestore');

const VOICE_COLLECTION = '_private_config';
const VOICE_DOCUMENT = 'admin_voice';
const CONSENT_ES = 'Soy el propietario de esta voz y doy mi consentimiento para que Google la utilice para crear un modelo de voz sintética.';
const MAX_AUDIO_BYTES = 4 * 1024 * 1024;
const MAX_SYNTHESIS_CHARS = 900;

function voiceRef(db) {
  return db.collection(VOICE_COLLECTION).doc(VOICE_DOCUMENT);
}

async function requireAdmin(db, uid, HttpsError) {
  const user = await db.collection('usuarios').doc(uid).get();
  if (!user.exists || String(user.data().rol || '').toLowerCase() !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administración puede configurar la voz oficial.');
  }
  return user;
}

async function getVoiceStatus(db) {
  const snapshot = await voiceRef(db).get();
  const data = snapshot.exists ? snapshot.data() || {} : {};
  const configured = Boolean(data.voiceCloningKey);
  const enabled = configured && data.enabled !== false;
  return {
    configured,
    enabled,
    provider: 'google-cloud-tts-chirp3-instant-custom-voice',
    updatedAt: dateValue(data.updatedAt),
    message: configured
      ? (enabled
          ? 'La voz oficial está configurada y disponible para Sauna IA y la Guía.'
          : 'La voz oficial existe, pero está desactivada temporalmente.')
      : 'Todavía no existe una voz oficial configurada.',
  };
}

async function enrollVoice({
  db,
  uid,
  consentUrl,
  referenceUrl,
  languageCode,
  projectId,
  bucket,
  HttpsError,
  ownsMedia,
}) {
  await requireAdmin(db, uid, HttpsError);
  if (!['es-US', 'es-ES'].includes(languageCode)) {
    throw new HttpsError('invalid-argument', 'El idioma de voz no es compatible.');
  }
  if (!ownsMedia([consentUrl, referenceUrl], uid, bucket)) {
    throw new HttpsError(
      'permission-denied',
      'Las grabaciones deben pertenecer a la cuenta administradora actual.',
    );
  }

  const [consentBytes, referenceBytes] = await Promise.all([
    downloadAudio(consentUrl),
    downloadAudio(referenceUrl),
  ]);
  const accessToken = await cloudAccessToken();
  const response = await fetch(
    'https://texttospeech.googleapis.com/v1beta1/voices:generateVoiceCloningKey',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'x-goog-user-project': projectId,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify({
        reference_audio: {
          audio_config: { audio_encoding: 'LINEAR16' },
          content: referenceBytes.toString('base64'),
        },
        voice_talent_consent: {
          audio_config: { audio_encoding: 'LINEAR16' },
          content: consentBytes.toString('base64'),
        },
        consent_script: CONSENT_ES,
        language_code: languageCode,
      }),
      signal: AbortSignal.timeout(60000),
    },
  );
  const payload = await readJson(response);
  if (!response.ok) throw providerError(response.status, payload, HttpsError);
  const key = String(payload.voiceCloningKey || '').trim();
  if (!key) {
    throw new HttpsError(
      'unavailable',
      'Google Cloud no devolvió una clave de voz utilizable.',
    );
  }

  await voiceRef(db).set(
    {
      voiceCloningKey: key,
      languageCode,
      enabled: true,
      provider: 'chirp3-instant-custom-voice',
      createdBy: uid,
      consentUrl,
      referenceUrl,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return getVoiceStatus(db);
}

async function setVoiceEnabled({ db, uid, enabled, HttpsError }) {
  await requireAdmin(db, uid, HttpsError);
  const snapshot = await voiceRef(db).get();
  if (!snapshot.exists || !snapshot.data().voiceCloningKey) {
    throw new HttpsError('failed-precondition', 'Primero crea una voz oficial.');
  }
  await voiceRef(db).update({
    enabled: Boolean(enabled),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return getVoiceStatus(db);
}

async function synthesizeVoice({ db, uid, text, projectId, HttpsError }) {
  const clean = String(text || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, MAX_SYNTHESIS_CHARS);
  if (!clean) {
    throw new HttpsError('invalid-argument', 'No hay texto para convertir a voz.');
  }
  await reserveVoiceRequest(db, uid, HttpsError);
  const snapshot = await voiceRef(db).get();
  const data = snapshot.exists ? snapshot.data() || {} : {};
  const key = String(data.voiceCloningKey || '').trim();
  if (!key || data.enabled === false) {
    return { available: false, mimeType: 'audio/mpeg', audioBase64: '' };
  }

  const accessToken = await cloudAccessToken();
  const response = await fetch(
    'https://texttospeech.googleapis.com/v1beta1/text:synthesize',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'x-goog-user-project': projectId,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: JSON.stringify({
        input: { text: clean },
        voice: {
          language_code: String(data.languageCode || 'es-US'),
          voice_clone: { voice_cloning_key: key },
        },
        audioConfig: { audioEncoding: 'MP3', speakingRate: 1.02 },
      }),
      signal: AbortSignal.timeout(35000),
    },
  );
  const payload = await readJson(response);
  if (!response.ok) throw providerError(response.status, payload, HttpsError);
  const audio = String(payload.audioContent || '').trim();
  if (!audio) {
    throw new HttpsError('unavailable', 'El servicio de voz no devolvió audio.');
  }
  return { available: true, mimeType: 'audio/mpeg', audioBase64: audio };
}

async function downloadAudio(url) {
  const response = await fetch(url, {
    redirect: 'error',
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    throw new Error(`No se pudo descargar la grabación (${response.status}).`);
  }
  const announced = Number(response.headers.get('content-length') || 0);
  if (announced > MAX_AUDIO_BYTES) {
    throw new Error('La grabación excede el tamaño permitido.');
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  if (!buffer.length || buffer.length > MAX_AUDIO_BYTES) {
    throw new Error('La grabación está vacía o es demasiado grande.');
  }
  return buffer;
}

async function cloudAccessToken() {
  const response = await fetch(
    'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
    {
      headers: { 'Metadata-Flavor': 'Google' },
      signal: AbortSignal.timeout(8000),
    },
  );
  if (!response.ok) {
    throw new Error(
      `No fue posible obtener credenciales administradas (${response.status}).`,
    );
  }
  const payload = await response.json();
  const value = String((payload && payload.access_token) || '').trim();
  if (!value) {
    throw new Error(
      'No fue posible obtener credenciales administradas de Google Cloud.',
    );
  }
  return value;
}

async function reserveVoiceRequest(db, uid, HttpsError, now = Date.now()) {
  const ref = db.collection('_voice_limits').doc(uid);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() || {} : {};
    const minute = Math.floor(now / 60000);
    const count = data.minute === minute ? Number(data.count || 0) : 0;
    if (count >= 18) {
      throw new HttpsError(
        'resource-exhausted',
        'Demasiadas solicitudes de voz en este minuto.',
      );
    }
    transaction.set(ref, { minute, count: count + 1 }, { merge: true });
  });
}

function providerError(status, payload, HttpsError) {
  const message = String(
    (payload && payload.error && payload.error.message) || '',
  );
  if ([401, 403, 404].includes(status)) {
    return new HttpsError(
      'failed-precondition',
      'La voz personalizada necesita que Text-to-Speech/Instant Custom Voice esté habilitado y autorizado para este proyecto de Google Cloud.',
    );
  }
  if (status === 429) {
    return new HttpsError(
      'resource-exhausted',
      'El proveedor de voz alcanzó temporalmente su límite.',
    );
  }
  if (status === 400) {
    return new HttpsError(
      'invalid-argument',
      message || 'La grabación no cumple los requisitos del proveedor de voz.',
    );
  }
  return new HttpsError(
    'unavailable',
    message || 'El proveedor de voz no está disponible en este momento.',
  );
}

async function readJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

function dateValue(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  return null;
}

module.exports = {
  CONSENT_ES,
  getVoiceStatus,
  enrollVoice,
  setVoiceEnabled,
  synthesizeVoice,
};
