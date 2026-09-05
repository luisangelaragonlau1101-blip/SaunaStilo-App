function mexicoParts(date) {
  return Object.fromEntries(new Intl.DateTimeFormat('en-CA', {timeZone:'America/Mexico_City',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',weekday:'short',hourCycle:'h23'}).formatToParts(date).map(p=>[p.type,p.value]));
}
function clock(value, fallback) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(value || ''));
  if (!m || +m[1]>23 || +m[2]>59) return fallback;
  return +m[1]*60 + +m[2];
}
function reminderSlot({type, user, attendance = {}, now = new Date()}) {
  const p = mexicoParts(now);
  if (p.weekday === 'Sun' || (p.weekday === 'Sat' && user.trabajaSabados !== true) || user.rol === 'admin' || user.activo === false) return null;
  if (attendance.horaSalida) return null;
  if (type === 'entrada' && attendance.horaEntrada) return null;
  if (type === 'comida' && (!attendance.horaEntrada || attendance.salidaComidaSolicitada || attendance.salidaComidaReal)) return null;
  if (type === 'salida' && !attendance.horaEntrada) return null;
  const scheduled = type === 'entrada' ? clock(user.horaEntrada, 9*60) : type === 'salida' ? clock(user.horaSalida,19*60) : 15*60;
  const elapsed = +p.hour*60 + +p.minute - scheduled;
  if (elapsed < 0 || elapsed >= 60) return null;
  return {slot:Math.floor(elapsed/15),dateKey:`${p.year}${p.month}${p.day}`};
}
module.exports={reminderSlot};
