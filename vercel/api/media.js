import { randomUUID } from 'node:crypto';
import { del, issueSignedToken, presignUrl } from '@vercel/blob';

const FIREBASE_API_KEY =
  process.env.FIREBASE_WEB_API_KEY ||
  'AIzaSyCqvb1kOvxvPTZzCZLQx6aZgEBnC-AZnYE';
const MAX_BYTES = 50 * 1024 * 1024;
const ALLOWED_ORIGINS = new Set([
  'https://sauna-stilo-app-web.vercel.app',
  'https://luisangelaragonlau1101-blip.github.io',
]);

export default async function handler(request, response) {
  setCors(request, response);
  if (request.method === 'OPTIONS') {
    response.status(204).end();
    return;
  }
  if (request.method !== 'POST' && request.method !== 'DELETE') {
    response.setHeader('allow', 'POST, DELETE, OPTIONS');
    response.status(405).json({ error: 'Método no permitido.' });
    return;
  }

  try {
    const user = await verifyFirebaseUser(request);
    const body = await readJsonBody(request);
    if (request.method === 'DELETE' || body.action === 'delete') {
      await deleteOwnedBlob(user.localId, body);
      response.status(200).json({ ok: true });
      return;
    }

    const size = Number(body.size);
    if (!Number.isFinite(size) || size <= 0 || size > MAX_BYTES) {
      throw httpError(
        400,
        'Cada archivo puede pesar hasta 50 MB; la cantidad de archivos no está limitada.',
      );
    }
    const contentType = normalizeContentType(body.contentType);
    if (!isAllowedContentType(contentType)) {
      throw httpError(400, 'Ese tipo de archivo no está permitido.');
    }

    const fileName = safeFileName(body.fileName);
    const folder = safeFolder(body.folder);
    const pathname = [
      'sauna-stilo',
      user.localId,
      folder,
      `${Date.now()}-${randomUUID()}-${fileName}`,
    ]
      .filter(Boolean)
      .join('/');
    const validUntil = Date.now() + 10 * 60 * 1000;
    const signedToken = await issueSignedToken({
      pathname,
      operations: ['put'],
      validUntil,
      allowedContentTypes: [contentType],
      maximumSizeInBytes: size,
    });
    const { presignedUrl } = await presignUrl(signedToken, {
      operation: 'put',
      pathname,
      access: 'public',
      validUntil,
      allowedContentTypes: [contentType],
      maximumSizeInBytes: size,
      allowOverwrite: false,
      addRandomSuffix: false,
    });

    response.status(200).json({ uploadUrl: presignedUrl, pathname });
  } catch (error) {
    const status = Number.isInteger(error?.status) ? error.status : 500;
    const message =
      status >= 500
        ? 'No se pudo preparar el almacenamiento. Inténtalo de nuevo.'
        : error.message;
    if (status >= 500) console.error(error);
    response.status(status).json({ error: message });
  }
}

async function verifyFirebaseUser(request) {
  const authorization = request.headers.authorization || '';
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw httpError(401, 'Inicia sesión para subir archivos.');

  const verification = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(
      FIREBASE_API_KEY,
    )}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ idToken: match[1] }),
    },
  );
  const data = await verification.json().catch(() => ({}));
  const user = Array.isArray(data.users) ? data.users[0] : null;
  if (!verification.ok || !user?.localId) {
    throw httpError(401, 'Tu sesión venció. Vuelve a iniciar sesión.');
  }
  return user;
}

async function deleteOwnedBlob(uid, body) {
  const url = typeof body.url === 'string' ? body.url.trim() : '';
  const suppliedPath = typeof body.path === 'string' ? body.path.trim() : '';
  let pathname = suppliedPath;
  if (!pathname && url) {
    try {
      pathname = decodeURIComponent(new URL(url).pathname).replace(/^\/+/, '');
    } catch {
      throw httpError(400, 'La dirección del archivo no es válida.');
    }
  }
  if (!pathname.startsWith(`sauna-stilo/${uid}/`)) {
    throw httpError(403, 'No tienes permiso para eliminar ese archivo.');
  }
  if (!url || !url.includes('.blob.vercel-storage.com/')) {
    throw httpError(400, 'La dirección del archivo no pertenece al almacén.');
  }
  await del(url);
}

async function readJsonBody(request) {
  if (request.body && typeof request.body === 'object') return request.body;
  if (typeof request.body === 'string') {
    try {
      return JSON.parse(request.body);
    } catch {
      throw httpError(400, 'La solicitud no es válida.');
    }
  }
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
  } catch {
    throw httpError(400, 'La solicitud no es válida.');
  }
}

function setCors(request, response) {
  const origin = request.headers.origin;
  if (origin && (ALLOWED_ORIGINS.has(origin) || origin.startsWith('http://localhost:'))) {
    response.setHeader('access-control-allow-origin', origin);
    response.setHeader('vary', 'Origin');
  }
  response.setHeader('access-control-allow-methods', 'POST, DELETE, OPTIONS');
  response.setHeader(
    'access-control-allow-headers',
    'Authorization, Content-Type',
  );
}

function normalizeContentType(value) {
  const normalized = String(value || 'application/octet-stream')
    .split(';')[0]
    .trim()
    .toLowerCase();
  return normalized || 'application/octet-stream';
}

function isAllowedContentType(value) {
  if (value === 'text/html' || value === 'image/svg+xml') return false;
  return (
    value.startsWith('image/') ||
    value.startsWith('audio/') ||
    value.startsWith('video/') ||
    value.startsWith('text/') ||
    [
      'application/pdf',
      'application/zip',
      'application/x-zip-compressed',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/octet-stream',
    ].includes(value)
  );
}

function safeFileName(value) {
  const cleaned = String(value || 'archivo')
    .normalize('NFKD')
    .replace(/[^a-zA-Z0-9._-]+/g, '_')
    .replace(/^\.+/, '')
    .slice(-120);
  return cleaned || 'archivo';
}

function safeFolder(value) {
  return String(value || 'general')
    .split('/')
    .map((part) => part.replace(/[^a-zA-Z0-9_-]+/g, '_').slice(0, 60))
    .filter(Boolean)
    .slice(0, 6)
    .join('/');
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}
