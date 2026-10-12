import '../services/attendance_gateway_service.dart';

bool teamTaskOverdue(Map<String, dynamic> task, {DateTime? now}) {
  if (['en_revision', 'completado'].contains(task['status'])) return false;
  var due = DateTime.tryParse((task['dueAt'] ?? '').toString());
  final day = (task['dueDay'] ?? '').toString();
  if (due == null && RegExp(r'^\d{8}$').hasMatch(day)) {
    due = DateTime.utc(
      int.parse(day.substring(0, 4)),
      int.parse(day.substring(4, 6)),
      int.parse(day.substring(6)) + 1,
      6,
    );
  }
  return due != null && due.isBefore((now ?? DateTime.now()).toUtc());
}

bool teamTaskInPeriod(
  Map<String, dynamic> task,
  String period, {
  DateTime? today,
}) {
  if (period == 'all') return true;
  final current = today ?? AttendanceGatewayService.today;
  final start = switch (period) {
    'week' => current.subtract(Duration(days: current.weekday - 1)),
    'month' => DateTime(current.year, current.month, 1),
    _ => current,
  };
  final end = switch (period) {
    'week' => start.add(const Duration(days: 7)),
    'month' => DateTime(current.year, current.month + 1, 1),
    _ => start.add(const Duration(days: 1)),
  };
  final day = (task['day'] ?? '').toString();
  if (!RegExp(r'^\d{8}$').hasMatch(day)) return false;
  final first = AttendanceGatewayService.dayKey(start),
      after = AttendanceGatewayService.dayKey(end);
  return day.compareTo(first) >= 0 && day.compareTo(after) < 0 ||
      day.compareTo(first) < 0 && task['status'] != 'completado';
}

class TeamProgressStats {
  final int total, review, approved, overdue, percentage;
  const TeamProgressStats({
    required this.total,
    required this.review,
    required this.approved,
    required this.overdue,
    required this.percentage,
  });
  factory TeamProgressStats.from(Iterable<Map<String, dynamic>> tasks) {
    final rows = tasks.toList();
    return TeamProgressStats(
      total: rows.length,
      review: rows.where((t) => t['status'] == 'en_revision').length,
      approved: rows.where((t) => t['status'] == 'completado').length,
      overdue: rows.where(teamTaskOverdue).length,
      percentage: rows.isEmpty
          ? 0
          : (rows.fold<num>(
                      0,
                      (sum, t) =>
                          sum + ((t['percentage'] as num?) ?? 0).clamp(0, 100),
                    ) /
                    rows.length)
                .round(),
    );
  }
}
