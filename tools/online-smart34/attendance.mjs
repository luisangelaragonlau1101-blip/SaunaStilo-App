import { createHash } from 'node:crypto';

// Durable receipts use the already deployed app database. Firebase remains the
// administrative/payroll ledger. Only a verified administrator can synchronize
// receipts, with that administrator's short-lived token and Firestore rules.
const ROOT = 'projects/saunastiloapp-17e15/databases/(default)/documents';
const API = `https://firestore.googleapis.com/v1/${ROOT}`;
const WORKERS = new Set(['trabajador', 'maestro', 'almacenista']);
export const MOVEMENTS = Object.freeze({
  entrada: 'horaEntrada',
  solicitar_comida: 'salidaComidaSolicitada',
  salida_comida: 'salidaComidaReal',
  regreso_comida: 'regresoComidaReal',
  salida: 'horaSalida',
});
export const ZONES = [
  [19.26247565075755, -98.89430986717343, 35],
  [19.26236781757325, -98.89404650777578, 20],
  [19.2622796818614, -98.89399453997612, 20],
  [19.262236850336194, -98.89410702511668, 20],
  [19.26225529052317, -98.89396402984858, 20],
  [19.262421336025, -98.89423744753003, 10],
];
const DATE_FIELDS = new Set([
  'fecha',
  ...Object.values(MOVEMENTS),
  'salidaComidaReal',
]);
const ms = (value) =>
  typeof value === 'string' && Number.isFinite(Date.parse(value))
    ? Date.parse(value)
    : null;
export function dayKey(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Mexico_City',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
    .format(date)
    .replaceAll('-', '');
}
function inZone(lat, lon) {
  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lon) ||
    Math.abs(lat) > 90 ||
    Math.abs(lon) > 180
  )
    return false;
  const r = Math.PI / 180;
  return ZONES.some(([a, b, radius]) => {
    const h =
      Math.sin(((lat - a) * r) / 2) ** 2 +
      Math.cos(lat * r) * Math.cos(a * r) * Math.sin(((lon - b) * r) / 2) ** 2;
    return (
      12742000 * Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1 - h))) <=
      radius
    );
  });
}
function arrival(profile, now) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(profile.horaEntrada || '09:00');
  const scheduled =
    match && +match[1] < 24 && +match[2] < 60
      ? +match[1] * 60 + +match[2]
      : 540;
  const tolerance = Number.isFinite(profile.toleranciaMinutos)
    ? Math.max(0, Math.min(120, profile.toleranciaMinutos))
    : 11;
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', {
      timeZone: 'America/Mexico_City',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(now)
      .map((p) => [p.type, p.value]),
  );
  return +parts.hour * 60 + +parts.minute > scheduled + tolerance
    ? 'retardo'
    : 'a_tiempo';
}
export function decodeValue(value) {
  if ('timestampValue' in value) return value.timestampValue;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('arrayValue' in value)
    return (value.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in value) return decodeFields(value.mapValue.fields || {});
  return null;
}
const decodeFields = (fields) =>
  Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [k, decodeValue(v)]),
  );
export function encodeValue(value, field = '') {
  if (value == null) return { nullValue: null };
  if (DATE_FIELDS.has(field) && ms(value) !== null)
    return { timestampValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number')
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  if (Array.isArray(value))
    return { arrayValue: { values: value.map((v) => encodeValue(v)) } };
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value).map(([k, v]) => [k, encodeValue(v)]),
      ),
    },
  };
}
function summary(d) {
  const start = ms(d.horaEntrada),
    end = ms(d.horaSalida),
    food = ms(d.salidaComidaReal),
    back = ms(d.regresoComidaReal);
  const issues = [];
  if (start === null) issues.push('sin_entrada');
  if (end === null) issues.push('sin_salida');
  if (start !== null && end !== null && end < start)
    issues.push('salida_anterior_a_entrada');
  if (food !== null && start !== null && food < start)
    issues.push('comida_anterior_a_entrada');
  if (food === null && back !== null) issues.push('regreso_sin_salida_a_comer');
  if (food !== null && back === null) issues.push('comida_sin_regreso');
  if (food !== null && back !== null && back < food)
    issues.push('regreso_anterior_a_comida');
  if (
    end !== null &&
    ((food !== null && food > end) || (back !== null && back > end))
  )
    issues.push('comida_fuera_de_jornada');
  if (d.estatusComida === 'pendiente_aprobacion')
    issues.push('comida_pendiente_de_aprobacion');
  const gross =
    start !== null && end !== null && end >= start
      ? Math.floor((end - start) / 60000)
      : null;
  const meal =
    food === null && back === null
      ? 0
      : food !== null && back !== null && back >= food
        ? Math.floor((back - food) / 60000)
        : null;
  return {
    version: 1,
    minutosEntreEntradaYSalida: gross,
    minutosComida: meal,
    minutosSinComida:
      issues.length === 0 && gross !== null && meal !== null
        ? gross - meal
        : null,
    requiereRevision: issues.length > 0,
    incidencias: issues,
    soloInformativo: true,
  };
}

export function projectDay(base, events, uid, day) {
  const data = { ...base };
  const patch = {};
  const imported = { ...base.movimientosServidor };
  const canonical = {};
  // Append-only receipts cannot overwrite one another. Concurrent duplicate
  // taps reduce to the earliest receipt; there is one effective time per step.
  for (const e of [...events].sort(
    (a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id),
  )) {
    if (
      e.uid === uid &&
      e.day === day &&
      Object.hasOwn(MOVEMENTS, e.movement) &&
      ms(e.at) !== null
    )
      canonical[e.movement] ??= e;
  }
  for (const movement of Object.keys(MOVEMENTS)) {
    const e = canonical[movement],
      field = MOVEMENTS[movement];
    if (!e || imported[field]) continue; // Administrative corrections stay authoritative, including cleared fields.
    if (data[field] == null) {
      if (movement === 'entrada') {
        if (data.estatus === 'incapacidad_pagada') continue;
        Object.assign(patch, {
          id: `${uid}_${day}`,
          trabajadorId: uid,
          fecha: data.fecha || e.at,
          horaEntrada: e.at,
          estatus:
            data.estatusJustificacion === 'aprobada'
              ? 'justificado'
              : e.arrivalStatus,
          ubicacionValida: e.manual !== true,
          registroManual: e.manual === true,
          latitudRegistro: e.manual === true ? null : e.latitud,
          longitudRegistro: e.manual === true ? null : e.longitud,
        });
        if (!data.estatusComida) patch.estatusComida = 'ninguna';
      } else {
        if (ms(data.horaEntrada) === null) continue;
        const end = ms(data.horaSalida) ?? ms(canonical.salida?.at);
        if (movement !== 'salida' && end !== null && ms(e.at) > end) continue;
        patch[field] = e.at;
        if (movement === 'solicitar_comida' && !data.salidaComidaReal)
          patch.estatusComida = 'pendiente_aprobacion';
        if (movement === 'salida_comida') Object.assign(patch, {estatusComida: 'comiendo', registroComidaManual: true});
        if (movement === 'regreso_comida')
          Object.assign(patch, {
            estatusComida: 'finalizada',
            ubicacionRegresoComidaValida: e.manual !== true,
          });
      }
      Object.assign(data, patch);
    }
    imported[field] = e.id;
  }
  if (
    Object.keys(imported).length &&
    JSON.stringify(imported) !== JSON.stringify(base.movimientosServidor || {})
  )
    patch.movimientosServidor = imported;
  if (Object.keys(data).length) {
    const totals = summary(data);
    if (
      events.length &&
      JSON.stringify(totals) !== JSON.stringify(base.resumenJornada)
    )
      patch.resumenJornada = totals;
    data.resumenJornada = totals;
  }
  Object.assign(data, patch);
  return { data, patch, canonical };
}

export function createAttendanceService({
  db,
  Fault,
  fetcher = fetch,
  clock = () => new Date(),
}) {
  const check = (ok, message, status = 400) => {
    if (!ok) throw new Fault(message, status);
  };
  const table = (uid, day) =>
    `sauna-attendance:${createHash('sha256').update(uid).digest('hex')}:${day}`;
  const indexTable = (day) => `sauna-attendance-inbox:${day}`;
  function validDay(value) {
    check(
      typeof value === 'string' && /^20\d{6}$/.test(value),
      'Fecha inválida.',
    );
    const parsed = new Date(
      `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6)}T18:00:00Z`,
    );
    check(
      Number.isFinite(parsed.getTime()) &&
        dayKey(parsed) === value &&
        value <= dayKey(clock()),
      'Selecciona una fecha válida, hasta hoy.',
    );
    return value;
  }
  function target(b, u) {
    const uid = b.userId || u.uid;
    check(
      typeof uid === 'string' &&
        uid.length > 0 &&
        uid.length <= 128 &&
        !uid.includes('/'),
      'Cuenta inválida.',
    );
    check(
      uid === u.uid || u.role === 'admin',
      'Solo puedes consultar tu jornada.',
      403,
    );
    return uid;
  }
  async function receipts(uid, day) {
    const page = await db.list(table(uid, day), { limit: 100 });
    check(
      !page.nextToken,
      'El día requiere revisión: hay demasiados intentos. No se ocultaron movimientos.',
      409,
    );
    return page.items;
  }
  async function firestore(uid, day, token) {
    check(
      typeof token === 'string' && token.length > 0,
      'Inicia sesión nuevamente.',
      401,
    );
    const name = `${ROOT}/asistencias/${uid}_${day}`;
    // Ownership is the only filter. A cursor bounds the read to one record at
    // or before this day. Exact document-name equality makes Firestore evaluate
    // a missing resource and denies the first clock-in under existing rules.
    const response = await fetcher(`${API}:runQuery`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'asistencias' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'trabajadorId' },
              op: 'EQUAL',
              value: { stringValue: uid },
            },
          },
          orderBy: [
            { field: { fieldPath: '__name__' }, direction: 'DESCENDING' },
          ],
          startAt: { values: [{ referenceValue: name }], before: true },
          limit: 1,
        },
      }),
      signal: AbortSignal.timeout(12000),
    });
    check(
      response.ok,
      'No se pudo consultar la jornada existente. Vuelve a intentar.',
      response.status === 429 ? 429 : response.status === 403 ? 403 : 503,
    );
    const rows = await response.json();
    check(
      Array.isArray(rows) && !rows.some((r) => r.error),
      'No se confirmó la lectura de tu jornada.',
      503,
    );
    const found = rows.find((r) => r.document)?.document;
    const doc = found?.name === name ? found : null;
    const data = doc ? decodeFields(doc.fields || {}) : {};
    check(
      !doc || (doc.name === name && data.trabajadorId === uid),
      'El expediente requiere revisión.',
      409,
    );
    return { name, data, updateTime: doc?.updateTime };
  }
  async function state(uid, day, token) {
    const [base, events] = await Promise.all([
      firestore(uid, day, token),
      receipts(uid, day),
    ]);
    return { ...projectDay(base.data, events, uid, day), base, events };
  }
  const view = (s, uid, day) => ({
    supportsManual: true,
    asistenciaId: `${uid}_${day}`,
    day,
    data: s.data,
    pendingSync: Object.keys(s.patch).length > 0,
  });
  async function commit(base, patch, token) {
    if (!Object.keys(patch).length) return;
    const response = await fetcher(`${API}:commit`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        writes: [
          {
            update: {
              name: base.name,
              fields: Object.fromEntries(
                Object.entries(patch).map(([k, v]) => [k, encodeValue(v, k)]),
              ),
            },
            updateMask: { fieldPaths: Object.keys(patch) },
            currentDocument: base.updateTime
              ? { updateTime: base.updateTime }
              : { exists: false },
          },
        ],
      }),
      signal: AbortSignal.timeout(12000),
    });
    check(
      response.ok,
      response.status === 409
        ? 'La jornada cambió. Actualiza e intenta de nuevo.'
        : 'Los movimientos están guardados; no se confirmó su actualización administrativa.',
      response.status === 409
        ? 409
        : response.status === 429
          ? 429
          : response.status === 403
            ? 403
            : 503,
    );
    const result = await response.json();
    check(
      result.commitTime && result.writeResults?.length === 1,
      'No se confirmó la actualización administrativa.',
      503,
    );
  }
  async function sync(uid, day, u, token) {
    check(
      u.role === 'admin',
      'Solo Administración puede integrar registros.',
      403,
    );
    const s = await state(uid, day, token);
    await commit(s.base, s.patch, token);
    return Object.keys(s.patch).length > 0;
  }
  return async function attendance(action, b, u, { token } = {}) {
    check(
      u && (WORKERS.has(u.role) || u.role === 'admin'),
      'Tu perfil no tiene acceso.',
      403,
    );
    const day = validDay(b.day || dayKey(clock()));
    const uid = target(b, u);
    if (action === 'attendance-state')
      return view(await state(uid, day, token), uid, day);
    if (action === 'attendance-history') {
      check(
        Array.isArray(b.days) && b.days.length > 0 && b.days.length <= 7,
        'Consulta hasta siete días por página.',
      );
      const days = [...new Set(b.days.map(validDay))];
      const items = [];
      for (const selected of days)
        items.push(view(await state(uid, selected, token), uid, selected));
      return { items };
    }
    if (action === 'attendance-sync-page') {
      check(
        u.role === 'admin',
        'Solo Administración puede integrar registros.',
        403,
      );
      check(
        !b.cursor || (typeof b.cursor === 'string' && b.cursor.length <= 4096),
        'Página inválida.',
      );
      const page = await db.list(indexTable(day), {
        limit: 8,
        ...(b.cursor ? { nextToken: b.cursor } : {}),
      });
      let updated = 0;
      for (const owner of new Set(page.items.map((e) => e.uid)))
        if (await sync(owner, day, u, token)) updated++;
      return { day, updated, nextToken: page.nextToken || null };
    }
    if (action === 'attendance-approve') {
      check(
        u.role === 'admin',
        'Solo Administración puede autorizar la comida.',
        403,
      );
      check(
        day === dayKey(clock()),
        'Solo se autoriza la salida a comer de hoy. Para corregir otra fecha usa Editar hora.',
        409,
      );
      await sync(uid, day, u, token);
      const s = await state(uid, day, token),
        d = s.base.data;
      if (d.salidaComidaReal)
        return { ...view(s, uid, day), exito: true, yaRegistrada: true };
      check(
        ms(d.horaEntrada) !== null &&
          ms(d.salidaComidaSolicitada) !== null &&
          !d.horaSalida &&
          d.estatusComida === 'pendiente_aprobacion',
        'La comida ya no está pendiente en una jornada abierta.',
        409,
      );
      const at = clock().toISOString();
      check(
        ms(at) >= ms(d.salidaComidaSolicitada),
        'Revisa la hora de la solicitud.',
        409,
      );
      const patch = {
        salidaComidaReal: at,
        estatusComida: 'comiendo',
        historialModificaciones: [
          ...(d.historialModificaciones || []),
          `Comida autorizada por ${u.name} (${u.uid}) el ${at}`,
        ],
      };
      patch.resumenJornada = summary({ ...d, ...patch });
      await commit(s.base, patch, token);
      return { ...view(await state(uid, day, token), uid, day), exito: true };
    }
    check(action === 'attendance-record', 'Acción no reconocida.', 404);
    check(
      (WORKERS.has(u.role) || (u.role === 'admin' && b.manual === true)) && uid === u.uid,
      'Administración supervisa; cada integrante registra su propia jornada.',
      403,
    );
    const movement = b.movement;
    check(Object.hasOwn(MOVEMENTS, movement), 'Movimiento inválido.');
    check(
      day === dayKey(clock()),
      'Cambió el día. Actualiza tu jornada antes de registrar.',
      409,
    );
    const s = await state(uid, day, token),
      d = s.data,
      field = MOVEMENTS[movement];
    if (d[field] != null) {
      check(ms(d[field]) !== null, 'La hora guardada requiere revisión.', 409);
      return {
        ...view(s, uid, day),
        exito: true,
        yaRegistrada: true,
        mensaje: 'Ya estaba registrado. Se conserva la hora original.',
      };
    }
    check(
      !s.canonical[movement],
      'Este movimiento ya fue revisado por Administración. Consulta tu jornada.',
      409,
    );
    check(
      b.manual === true || movement === 'solicitar_comida' || inZone(b.latitud, b.longitud),
      'Debes estar en una zona autorizada de Sauna Stilo. No se guardó el movimiento.',
      409,
    );
    check(movement !== 'salida_comida' || b.manual === true, 'Usa el registro sencillo para iniciar tu comida.');
    const at = clock().toISOString();
    check(
      dayKey(new Date(at)) === day,
      'Cambió el día. Actualiza tu jornada.',
      409,
    );
    if (movement === 'entrada') {
      check(
        !d.horaSalida &&
          !d.salidaComidaReal &&
          !d.regresoComidaReal &&
          d.estatus !== 'incapacidad_pagada',
        'El expediente necesita revisión antes de registrar una entrada.',
        409,
      );
    } else {
      check(
        ms(d.horaEntrada) !== null &&
          ms(d.horaEntrada) <= ms(at) &&
          !d.horaSalida,
        'Primero registra tu entrada en una jornada abierta.',
        409,
      );
      if (movement === 'solicitar_comida' || movement === 'salida_comida')
        check(
          !d.salidaComidaReal && !d.regresoComidaReal,
          'La comida ya tiene movimientos.',
          409,
        );
      if (movement === 'regreso_comida')
        check(
          ms(d.salidaComidaReal) !== null &&
            ms(d.salidaComidaReal) >= ms(d.horaEntrada) &&
            ms(d.salidaComidaReal) <= ms(at) &&
            d.estatusComida === 'comiendo',
          'Registra tu salida a comer; las solicitudes anteriores requieren autorización.',
          409,
        );
    }
    check(
      s.events.length < 80,
      'Demasiados intentos para este día. Consulta a Administración.',
      429,
    );
    // Index first: a failed receipt may leave an empty inbox pointer, never an
    // undiscoverable successful attendance receipt. Tokens are never persisted.
    if (!s.events.length) {
      const [indexId] = await db.add(indexTable(day), [{ uid, day }]);
      check(
        indexId,
        'No se confirmó el registro. Vuelve a consultar tu jornada.',
        503,
      );
    }
    const [id] = await db.add(table(uid, day), [
      {
        uid,
        day,
        movement,
        at,
        actorId: u.uid,
        manual: b.manual === true,
        arrivalStatus: arrival(u, new Date(at)),
        ...(b.manual !== true && movement !== 'solicitar_comida'
          ? { latitud: b.latitud, longitud: b.longitud }
          : {}),
      },
    ]);
    check(
      id,
      'No se confirmó el guardado. Consulta tu jornada antes de reintentar.',
      503,
    );
    const saved = await state(uid, day, token);
    check(
      ms(saved.data[field]) !== null,
      'El estado cambió mientras registrabas. Revisa tu jornada.',
      409,
    );
    const messages = {
      entrada: 'Entrada guardada.',
      salida_comida: 'Salida a comer guardada.',
      solicitar_comida:
        'Solicitud de comida guardada. Espera la autorización de Administración.',
      regreso_comida: 'Regreso de comida guardado.',
      salida: 'Salida guardada. Tu jornada terminó.',
    };
    return {
      ...view(saved, uid, day),
      exito: true,
      mensaje: messages[movement],
    };
  };
}
