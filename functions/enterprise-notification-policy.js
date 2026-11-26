'use strict';
const {active, canViewFinance} = require('./enterprise-access');

const NOTIFICATION_CATEGORIES = Object.freeze(['tareas','compras','finanzas','instalaciones','jornada','cumpleanos','generales']);
function notificationCategory(data) {
  const type = String(data.tipo || '');
  if (data.privadoFinanzas === true || /^(factura|finanza|gestion_factura)/.test(type)) return 'finanzas';
  if (/^(compra|solicitud_compra)/.test(type)) return 'compras';
  if (/^(instalacion|preparacion|herramienta_firma|devolucion_instalacion)/.test(type)) return 'instalaciones';
  if (/^(tarea|actividad)/.test(type)) return 'tareas';
  if (/^asistencia_/.test(type)) return 'jornada';
  if (/^cumpleanos/.test(type)) return 'cumpleanos';
  return 'generales';
}
function shouldDeliverNotification(profile, data, preferences = {}) {
  if (!active(profile) || data.cancelada === true) return false;
  if ((data.privadoFinanzas === true || notificationCategory(data) === 'finanzas') && !canViewFinance(profile)) return false;
  return preferences[notificationCategory(data)] !== false;
}
function localParts(now, timeZone = 'America/Mexico_City') {
  try {
    return Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',weekday:'short',hourCycle:'h23'}).formatToParts(now).map(p=>[p.type,p.value]));
  } catch (_) { return localParts(now, 'America/Mexico_City'); }
}
function clock(value, fallback) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(String(value || ''));
  return match && +match[1] < 24 && +match[2] < 60 ? +match[1] * 60 + +match[2] : fallback;
}
function milliseconds(value) {
  if (value instanceof Date) return value.getTime();
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  return NaN;
}
function restDay(profile, parts) {
  const weekday = {Mon:1,Tue:2,Wed:3,Thu:4,Fri:5,Sat:6,Sun:7}[parts.weekday];
  const rest = Array.isArray(profile.diasDescanso) ? profile.diasDescanso : profile.trabajaSabados === true ? [7] : [6,7];
  if (rest.includes(weekday)) return true;
  const day = `${parts.year}-${parts.month}-${parts.day}`;
  return [...(Array.isArray(profile.permisos) ? profile.permisos : []), ...(Array.isArray(profile.vacaciones) ? profile.vacaciones : [])]
    .some(p => p && ['aprobado','aprobada'].includes(p.estado) && /^\d{4}-\d{2}-\d{2}$/.test(p.inicio) && /^\d{4}-\d{2}-\d{2}$/.test(p.fin) && p.inicio <= day && p.fin >= day);
}
function workdayReminders(profile, attendance = {}, now = new Date(), preferences = {}) {
  if (!active(profile) || !['trabajador','maestro','almacenista'].includes(profile.rol) || preferences.jornada === false || attendance.horaSalida) return [];
  const parts = localParts(now); // Existing ledger keys are always Mexico City days.
  if (restDay(profile, parts) || attendance.estatusJustificacion === 'aprobada' && !attendance.horaEntrada || attendance.estatus === 'incapacidad_pagada') return [];
  const dayKey = parts.year + parts.month + parts.day;
  const minute = +parts.hour * 60 + +parts.minute;
  const entry = clock(profile.horaEntrada, 540), exit = clock(profile.horaSalida, 1140);
  const lunch = clock(profile.horaComida, 900);
  const lunchMinutes = Number.isInteger(profile.minutosComida) && profile.minutosComida >= 10 && profile.minutosComida <= 180 ? profile.minutosComida : 70;
  // At most one notice per action/day. The scheduled job runs every five
  // minutes, with a short catch-up window, rather than repeated nags.
  const due = (scheduled) => minute >= scheduled && minute < scheduled + 30;
  const events = [];
  if (!attendance.horaEntrada && due(entry)) events.push({action:'entrada',title:'Tu jornada está por comenzar',body:'Recuerda registrar tu entrada en Mi jornada.'});
  if (attendance.horaEntrada && !attendance.salidaComidaSolicitada && !attendance.salidaComidaReal && due(lunch) && minute < exit) events.push({action:'comida',title:'🍽️ Hora de comida',body:'Recuerda registrar tu salida a comer en Mi jornada.'});
  const departed = milliseconds(attendance.salidaComidaReal);
  if (Number.isFinite(departed) && !attendance.regresoComidaReal) {
    const elapsed = Math.floor((now.getTime() - departed) / 60000);
    if (elapsed >= lunchMinutes && elapsed < lunchMinutes + 30 && minute < exit) events.push({action:'regreso_comida',title:'⏰ ¿Ya regresaste de comer?',body:'Registra tu regreso en Mi jornada.'});
  }
  if (attendance.horaEntrada && due(exit)) events.push({action:'salida',title:'Fin de jornada',body:'Recuerda registrar tu salida antes de retirarte.'});
  return events.map(e=>({...e,dayKey}));
}
function reminderCompleted(action, attendance) {
  return !!attendance.horaSalida || ({entrada:!!attendance.horaEntrada,comida:!!(attendance.salidaComidaSolicitada || attendance.salidaComidaReal),regreso_comida:!!attendance.regresoComidaReal,salida:!!attendance.horaSalida})[action] === true;
}
module.exports = {NOTIFICATION_CATEGORIES, notificationCategory, shouldDeliverNotification, localParts, workdayReminders, reminderCompleted, restDay};
