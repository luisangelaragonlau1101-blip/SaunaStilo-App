const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const base = require('./index');
const { decodeVoiceWav } = require('./voice-audio');
const { saunaAssistantV2 } = require('./assistant-v2');
const { assignProjectActivity, repeatWorkdayReminders } = require('./team-operations');
const {
  getVoiceStatus,
  enrollVoice,
  setVoiceEnabled,
  synthesizeVoice,
} = require('./voice-service');

const STORAGE_BUCKET = 'saunastiloapp-17e15.firebasestorage.app';
const GOOGLE_CLOUD_PROJECT =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  'saunastiloapp-17e15';

const getAdminVoiceStatus = onCall({ timeoutSeconds: 20 }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  return getVoiceStatus(getFirestore());
});

const enrollAdminVoice = onCall(
  { timeoutSeconds: 90, memory: '1GiB' },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    const db = getFirestore();
    const profile = await db.collection('usuarios').doc(uid).get();
    if (!profile.exists || profile.data().rol !== 'admin') throw new HttpsError('permission-denied', 'Solo administración puede configurar la voz.');
    const consentBytes = decodeVoiceWav(request.data && request.data.consentBase64, HttpsError);
    const referenceBytes = decodeVoiceWav(request.data && request.data.referenceBase64, HttpsError);
    return enrollVoice({
      db: getFirestore(),
      uid,
      consentBytes,
      referenceBytes,
      languageCode: ['es-US', 'es-ES'].includes(
        request.data && request.data.languageCode,
      )
        ? request.data.languageCode
        : 'es-US',
      projectId: GOOGLE_CLOUD_PROJECT,
      bucket: STORAGE_BUCKET,
      HttpsError,
    });
  },
);

const setAdminVoiceEnabled = onCall(
  { timeoutSeconds: 20 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    return setVoiceEnabled({
      db: getFirestore(),
      uid,
      enabled: request.data && request.data.enabled === true,
      HttpsError,
    });
  },
);

const synthesizeAdminVoice = onCall(
  { timeoutSeconds: 45, memory: '512MiB' },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    const profile = await getFirestore().collection('usuarios').doc(uid).get();
    if (!profile.exists || !['admin', 'maestro', 'almacenista', 'trabajador'].includes(profile.data().rol)) throw new HttpsError('permission-denied', 'Tu perfil no tiene acceso al servicio de voz.');
    return synthesizeVoice({
      db: getFirestore(),
      uid,
      text: request.data && request.data.text,
      projectId: GOOGLE_CLOUD_PROJECT,
      HttpsError,
    });
  },
);

module.exports = {
  ...base,
  saunaAssistantV2,
  getAdminVoiceStatus,
  enrollAdminVoice,
  setAdminVoiceEnabled,
  synthesizeAdminVoice,
  assignProjectActivity,
  repeatWorkdayReminders,
};
