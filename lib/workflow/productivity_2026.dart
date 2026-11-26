import 'task_lifecycle.dart';

DateTime workDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime companyDay(DateTime instant) {
  final mexico = instant.toUtc().subtract(const Duration(hours: 6));
  return DateTime(mexico.year, mexico.month, mexico.day);
}

/// One record per canonical actividades document, including shared activities.
class WorkActivity {
  final String id;
  final List<String> assignees;
  final DateTime? assignedDay, approvedDay;
  final String status;
  const WorkActivity({
    required this.id,
    required this.assignees,
    this.assignedDay,
    this.approvedDay,
    required this.status,
  });
  bool get approved => status == 'completado';
  factory WorkActivity.fromMap(Map<String, dynamic> row) {
    DateTime? parse(dynamic value, {bool instant = true}) {
      final date = value is DateTime
          ? value
          : value is String
          ? DateTime.tryParse(value)
          : null;
      return date == null
          ? null
          : instant
          ? companyDay(date)
          : workDay(date);
    }

    DateTime? fromDay(dynamic value) {
      final text = value?.toString() ?? '';
      if (!RegExp(r'^\d{8}$').hasMatch(text)) return null;
      final parsed = DateTime.tryParse(
        '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6)}',
      );
      if (parsed == null ||
          '${parsed.year.toString().padLeft(4, '0')}${parsed.month.toString().padLeft(2, '0')}${parsed.day.toString().padLeft(2, '0')}' !=
              text)
        return null;
      return workDay(parsed);
    }

    final ids = <String>{};
    for (final key in ['userIds', 'asignadosIds']) {
      final value = row[key];
      if (value is List)
        ids.addAll(value.whereType<String>().where((v) => v.isNotEmpty));
    }
    for (final key in ['userId', 'asignadoATrabajadorId']) {
      final value = row[key];
      if (value is String && value.isNotEmpty) ids.add(value);
    }
    final normalized = row.containsKey('status');
    final approval = row['approvedAt'] ?? row['aprobadoEn'];
    final rawStatus = row['status'] ?? row['estatus'];
    return WorkActivity(
      id: (row['taskId'] ?? row['id'] ?? '').toString(),
      assignees: ids.toList(growable: false),
      assignedDay:
          parse(
            row['assignedAt'] ?? row['fechaAsignada'] ?? row['fechaInicio'],
          ) ??
          fromDay(row['day']),
      approvedDay: parse(approval),
      // Adapter status already distinguishes delivery from approval. Raw data
      // requires a real approval timestamp, including legacy completed states.
      status: normalized
          ? rawStatus?.toString() ?? 'pendiente'
          : taskStatus(rawStatus, approved: approval != null),
    );
  }
}

class WorkSchedule {
  final Set<int> restWeekdays;
  final Set<DateTime> approvedLeaveDays;
  const WorkSchedule({
    this.restWeekdays = const {6, 7},
    this.approvedLeaveDays = const {},
  });
  bool works(DateTime date) =>
      !restWeekdays.contains(date.weekday) &&
      !approvedLeaveDays.contains(workDay(date));
}

class ProductivityBucket {
  final DateTime day;
  final int approved;
  const ProductivityBucket(this.day, this.approved);
}

class WorkProductivity {
  final int approvedWeek,
      approvedMonth,
      pending,
      review,
      currentStreak,
      bestStreak,
      unknownApprovalDate;
  final List<ProductivityBucket> weekly, monthly;
  final int uniqueActivities;
  final DateTime observedSince;
  final bool partial;
  const WorkProductivity({
    required this.approvedWeek,
    required this.approvedMonth,
    required this.pending,
    required this.review,
    required this.currentStreak,
    required this.bestStreak,
    required this.unknownApprovalDate,
    required this.weekly,
    required this.monthly,
    required this.uniqueActivities,
    required this.observedSince,
    this.partial = false,
  });

  factory WorkProductivity.fromActivities(
    Iterable<WorkActivity> activities, {
    required DateTime today,
    String? personId,
    WorkSchedule schedule = const WorkSchedule(),
    DateTime? observedSince,
    bool partial = false,
  }) {
    final current = workDay(today);
    final since = workDay(
      observedSince ?? current.subtract(const Duration(days: 89)),
    );
    final unique = <String, WorkActivity>{};
    for (final item in activities) {
      if (item.id.isEmpty ||
          personId != null && !item.assignees.contains(personId))
        continue;
      unique[item.id] = item;
    }
    final rows = unique.values.toList(growable: false);
    final monday = current.subtract(Duration(days: current.weekday - 1));
    final month = DateTime(current.year, current.month, 1);
    final nextMonth = DateTime(current.year, current.month + 1, 1);
    final approvals = <DateTime, int>{};
    var unknown = 0;
    for (final item in rows.where((t) => t.approved)) {
      final day = item.approvedDay;
      if (day == null) {
        unknown++;
        continue;
      }
      if (!day.isAfter(current))
        approvals.update(day, (n) => n + 1, ifAbsent: () => 1);
    }
    int count(DateTime start, DateTime end) => approvals.entries
        .where((v) => !v.key.isBefore(start) && v.key.isBefore(end))
        .fold(0, (n, v) => n + v.value);
    final assigned = <DateTime, List<WorkActivity>>{};
    for (final item in rows) {
      final day = item.assignedDay;
      if (day == null ||
          day.isBefore(since) ||
          day.isAfter(current) ||
          !schedule.works(day))
        continue;
      assigned.putIfAbsent(day, () => []).add(item);
    }
    final days = assigned.keys.toList()..sort();
    var streak = 0, best = 0;
    for (final day in days) {
      final hasApproved = assigned[day]!.any(
        (t) =>
            t.approved &&
            t.approvedDay != null &&
            !t.approvedDay!.isAfter(current),
      );
      if (hasApproved) {
        streak++;
        if (streak > best) best = streak;
      }
      // Today's work can still be delivered. It does not break yesterday's
      // streak until the workday has ended. Days without assignments, approved
      // leave and weekly rest never add points or interrupt the sequence.
      else if (day.isBefore(current)) {
        streak = 0;
      }
    }
    final monthly = <ProductivityBucket>[];
    for (
      var start = month;
      start.isBefore(nextMonth);
      start = start.add(const Duration(days: 7))
    ) {
      final end = start.add(const Duration(days: 7));
      monthly.add(
        ProductivityBucket(
          start,
          count(start, end.isAfter(nextMonth) ? nextMonth : end),
        ),
      );
    }
    return WorkProductivity(
      approvedWeek: count(monday, monday.add(const Duration(days: 7))),
      approvedMonth: count(month, nextMonth),
      pending: rows
          .where(
            (t) =>
                !t.approved &&
                t.status != 'en_revision' &&
                (t.assignedDay == null || !t.assignedDay!.isAfter(current)),
          )
          .length,
      review: rows.where((t) => t.status == 'en_revision').length,
      currentStreak: streak,
      bestStreak: best,
      unknownApprovalDate: unknown,
      weekly: [
        for (var d = 0; d < 7; d++)
          ProductivityBucket(
            monday.add(Duration(days: d)),
            approvals[monday.add(Duration(days: d))] ?? 0,
          ),
      ],
      monthly: monthly,
      uniqueActivities: rows.length,
      observedSince: since,
      partial: partial,
    );
  }
}
