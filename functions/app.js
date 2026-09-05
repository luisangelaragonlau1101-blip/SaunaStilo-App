const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const base = require('./index');
const { ownedMediaUrls } = require('./assistant-policy');
const { saunaAssistantV2 } = require('./assistant-v2');
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
    const consentUrl = safeMediaUrl(request.data && request.data.consentUrl);
    const referenceUrl = safeMediaUrl(
      request.data && request.data.referenceUrl,
    );
    if (!consentUrl || !referenceUrl) {
      throw new HttpsError(
        'invalid-argument',
        'Las dos grabaciones son obligatorias.',
      );
    }
    return enrollVoice({
      db: getFirestore(),
      uid,
      consentUrl,
      referenceUrl,
      languageCode: ['es-US', 'es-ES'].includes(
        request.data && request.data.languageCode,
      )
        ? request.data.languageCode
        : 'es-US',
      projectId: GOOGLE_CLOUD_PROJECT,
      bucket: STORAGE_BUCKET,
      HttpsError,
      ownsMedia: ownedMediaUrls,
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
    return synthesizeVoice({
      db: getFirestore(),
      uid,
      text: request.data && request.data.text,
      projectId: GOOGLE_CLOUD_PROJECT,
      HttpsError,
    });
  },
);

function safeMediaUrl(value) {
  try {
    const url = new URL(String(value || ''));
    if (url.protocol !== 'https:') return '';
    const firebasePrefix = `/v0/b/${STORAGE_BUCKET}/o/`;
    if (
      url.hostname === 'firebasestorage.googleapis.com' &&
      url.pathname.startsWith(firebasePrefix)
    ) {
      return url.toString();
    }
    if (
      url.hostname === 'storage.googleapis.com' &&
      url.pathname.startsWith(`/${STORAGE_BUCKET}/`)
    ) {
      return url.toString();
    }
    return '';
  } catch (_) {
    return '';
  }
}

module.exports = {
  ...base,
  saunaAssistantV2,
  getAdminVoiceStatus,
  enrollAdminVoice,
  setAdminVoiceEnabled,
  synthesizeAdminVoice,
};
