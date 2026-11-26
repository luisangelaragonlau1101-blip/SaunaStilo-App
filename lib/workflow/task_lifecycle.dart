/// Keep legacy deliveries reviewable until Administration explicitly approves.
String taskStatus(dynamic value, {bool approved = false}) {
  final status = (value ?? 'pendiente')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  if (const [
    'completado',
    'completada',
    'completed',
    'finalizado',
    'finalizada',
    'terminado',
    'terminada',
  ].contains(status)) {
    return approved ? 'completado' : 'en_revision';
  }
  if (status == 'en_proceso' || status == 'progreso') return 'en_progreso';
  return status.isEmpty ? 'pendiente' : status;
}

bool taskFallsOnDay(
  String assigned,
  String due,
  String day, {
  bool carryPending = false,
  bool approved = false,
}) {
  if (day.length == 6) return assigned.startsWith(day);
  if (!RegExp(r'^20\d{6}$').hasMatch(day)) return false;
  if (assigned == day) return true;
  return assigned.compareTo(day) <= 0 &&
      (due.compareTo(day) >= 0 || carryPending && !approved);
}

/// A shared activity remains one document and one delivery. The legacy primary
/// responsible person stays readable while every assigned member can work on it.
List<String> taskResponsibleIds(Map<String, dynamic> task) {
  final ids = <String>{};
  for (final key in ['userIds', 'asignadosIds']) {
    final value = task[key];
    if (value is Iterable && value is! String) {
      ids.addAll(value.whereType<String>().where((id) => id.isNotEmpty));
    }
  }
  for (final key in ['userId', 'asignadoATrabajadorId']) {
    final value = task[key];
    if (value is String && value.isNotEmpty) ids.add(value);
  }
  return ids.toList(growable: false);
}

bool taskAssignedTo(Map<String, dynamic> task, String uid) =>
    uid.isNotEmpty && taskResponsibleIds(task).contains(uid);
