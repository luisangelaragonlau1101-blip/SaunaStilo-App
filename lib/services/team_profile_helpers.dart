// Profile fields contain only information people choose to share with their team.
DateTime nextTeamBirthday(DateTime birth, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime occurrence(int year) {
    final lastDay = DateTime(year, birth.month + 1, 0).day;
    return DateTime(year, birth.month, birth.day > lastDay ? lastDay : birth.day);
  }
  final thisYear = occurrence(today.year);
  return thisYear.isBefore(today) ? occurrence(today.year + 1) : thisYear;
}
DateTime mexicoToday([DateTime? instant]) {
  final local = (instant ?? DateTime.now()).toUtc().subtract(const Duration(hours: 6));
  return DateTime(local.year, local.month, local.day);
}
List<String> profileTags(dynamic value) => (value is List ? value.map((v) => v.toString()) : (value?.toString() ?? '').split(','))
    .map((v) => v.trim()).where((v) => v.isNotEmpty).take(12).toList(growable: false);
