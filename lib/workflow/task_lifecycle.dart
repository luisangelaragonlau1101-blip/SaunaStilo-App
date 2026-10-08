/// Keep legacy deliveries reviewable until Administration explicitly approves.
String taskStatus(dynamic value, {bool approved = false}) {
  final status = (value ?? 'pendiente').toString().trim().toLowerCase()
      .replaceAll('-', '_').replaceAll(' ', '_');
  if (const ['completado', 'completada', 'completed', 'finalizado',
    'finalizada', 'terminado', 'terminada'].contains(status)) {
    return approved ? 'completado' : 'en_revision';
  }
  if (status == 'en_proceso' || status == 'progreso') return 'en_progreso';
  return status.isEmpty ? 'pendiente' : status;
}

bool taskFallsOnDay(String assigned, String due, String day,
    {bool carryPending = false, bool approved = false}) {
  if (day.length == 6) return assigned.startsWith(day);
  if (!RegExp(r'^20\d{6}$').hasMatch(day)) return false;
  if (assigned == day) return true;
  return assigned.compareTo(day) <= 0 &&
      (due.compareTo(day) >= 0 || carryPending && !approved);
}
