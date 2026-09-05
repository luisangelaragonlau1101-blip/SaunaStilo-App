// Shared, dependency-free policy: testable without production credentials.
function generationConfig(systemInstruction) {
  // Gemini 3.7 does not accept deprecated sampling controls (temperature/topP/topK).
  return { maxOutputTokens: 2048, systemInstruction };
}
function assistantFailure(error) {
  const status = Number(error && (error.status || error.statusCode || error.code));
  if ([401, 403, 404].includes(status)) {
    return { code: 'failed-precondition', message: 'Administración debe revisar el motor de IA, la API habilitada y los permisos de la cuenta de servicio.' };
  }
  if (status === 429) return { code: 'resource-exhausted', message: 'Se alcanzó el límite de uso de IA. Intenta más tarde.' };
  if (status === 400) return { code: 'invalid-argument', message: 'La IA no pudo procesar la pregunta o los archivos adjuntos.' };
  if ([408, 504].includes(status) || error && error.name === 'TimeoutError') {
    return { code: 'deadline-exceeded', message: 'La IA tardó demasiado en responder.' };
  }
  return { code: 'unavailable', message: 'El motor inteligente no está disponible en este momento.' };
}
async function reserveAssistantRequest(db, uid, HttpsError, now = Date.now()) {
  // Server-side limits, not client-controlled. One document per account; no accumulating per-minute records.
  const ref = db.collection('_assistant_limits').doc(uid);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};
    const minute = Math.floor(now / 60000);
    const day = Math.floor(now / 86400000);
    const minuteCount = data.minute === minute ? Number(data.minuteCount || 0) : 0;
    const dayCount = data.day === day ? Number(data.dayCount || 0) : 0;
    if (minuteCount >= 8 || dayCount >= 150) throw new HttpsError('resource-exhausted', 'Límite temporal del asistente alcanzado.');
    transaction.set(ref, { minute, day, minuteCount: minuteCount + 1, dayCount: dayCount + 1 });
  });
}
function ownedMediaUrls(urls, uid, bucket) {
  for (const value of urls) {
    const url = new URL(value);
    let object;
    if (url.hostname === 'firebasestorage.googleapis.com') {
      const prefix = `/v0/b/${bucket}/o/`;
      if (!url.pathname.startsWith(prefix)) return false;
      object = decodeURIComponent(url.pathname.slice(prefix.length));
    } else if (url.hostname === 'storage.googleapis.com') {
      const prefix = `/${bucket}/`;
      if (!url.pathname.startsWith(prefix)) return false;
      object = decodeURIComponent(url.pathname.slice(prefix.length));
    } else return false;
    if (url.protocol !== 'https:' || !object.startsWith(`media/${uid}/`) || object.split('/').includes('..')) return false;
  }
  return true;
}
module.exports = { generationConfig, assistantFailure, reserveAssistantRequest, ownedMediaUrls };
