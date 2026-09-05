'use strict';

function canAssignProjectTask({uid, targetId, caller, target, project}) {
  if (!uid || !targetId || !caller || !target || !project || caller.activo === false || target.activo === false) return false;
  if (!['admin', 'maestro'].includes(caller.rol) || !['maestro', 'trabajador'].includes(target.rol)) return false;
  const members = Array.isArray(project.encargados) ? project.encargados : [];
  if (!members.includes(targetId)) return false;
  return caller.rol === 'admin' || members.includes(uid);
}

function validateTaskInput(data, now = Date.now()) {
  if (!data || typeof data !== 'object') throw new Error('invalid-input');
  const id = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
  if (!id(data.requestId) || !id(data.proyectoId) || !id(data.trabajadorId)) throw new Error('invalid-id');
  if (typeof data.titulo !== 'string' || data.titulo.trim().length < 3 || data.titulo.length > 150) throw new Error('invalid-title');
  if (typeof data.descripcion !== 'string' || data.descripcion.length > 2000) throw new Error('invalid-description');
  if (typeof data.fechaTermino !== 'string') throw new Error('invalid-deadline');
  const due = Date.parse(data.fechaTermino);
  if (!Number.isFinite(due) || due <= now || due > now + 366 * 86400000) throw new Error('invalid-deadline');
  return {requestId: data.requestId, proyectoId: data.proyectoId, trabajadorId: data.trabajadorId, titulo: data.titulo.trim(), descripcion: data.descripcion.trim(), fechaTermino: new Date(due).toISOString()};
}

function remindersDue(user, attendance, date) {
  if (!user || user.activo === false || user.rol === 'admin') return [];
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', {timeZone:'America/Mexico_City', weekday:'short', year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date).map(p=>[p.type,p.value]));
  if (parts.weekday === 'Sun' || (parts.weekday === 'Sat' && user.trabajaSabados !== true)) return [];
  const minute = Number(parts.hour) * 60 + Number(parts.minute);
  const clock = (value, fallback) => {const m = /^(\d{1,2}):(\d{2})$/.exec(String(value || ''));return m && +m[1]<24 && +m[2]<60 ? +m[1]*60 + +m[2] : fallback;};
  const record = attendance || {};
  const candidates = [
    ['entrada', clock(user.horaEntrada,540), !record.horaEntrada],
    ['comida', 900, !!record.horaEntrada && !record.salidaComidaSolicitada && !record.salidaComidaReal && !record.horaSalida],
    ['salida', clock(user.horaSalida,1140), !!record.horaEntrada && !record.horaSalida],
  ];
  return candidates.flatMap(([action, time, pending]) => {
    const slot = Math.floor((minute - time) / 15);
    return pending && slot >= 1 && slot <= 3 ? [{action,slot,dayKey:`${parts.year}${parts.month}${parts.day}`}]:[];
  });
}
module.exports = {canAssignProjectTask, validateTaskInput, remindersDue};
