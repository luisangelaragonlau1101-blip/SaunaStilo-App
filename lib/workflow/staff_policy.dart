/// Recipients complete assigned work; reporting extra work never creates a task.
bool canAssignWork(String role) => role == 'admin' || role == 'maestro';

int projectCompletion(Iterable<String> statuses) {
  final all = statuses.toList(growable: false);
  if (all.isEmpty) return 0;
  return (100 * all.where((s) => s == 'completado').length / all.length).round();
}

/// Remove presentation markup, never truncate the actual answer or its numbers.
String plainAssistantText(String text) {
  var s = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m[1]!);
  s = s.replaceAll(RegExp(r'\*\*|__|```[a-zA-Z]*|`'), '');
  s = s.replaceAllMapped(RegExp(r'(^|\s)\*([^*\n]+)\*(?=\s|[.,!?]|$)'), (m) => '${m[1]}${m[2]}');
  s = s.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
  s = s.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
  return s.trim();
}

List<String> spokenAnswerChunks(String text, {int limit = 1200}) {
  if (limit < 80) throw ArgumentError('Usa fragmentos de al menos 80 caracteres.');
  var rest = plainAssistantText(text).replaceAll(RegExp(r'\[\d+\]'), '')
      .replaceAll('• ', '').trim();
  final chunks = <String>[];
  while (rest.length > limit) {
    var split = rest.lastIndexOf(RegExp(r'[.!?\n]'), limit - 1);
    if (split < limit ~/ 2) split = rest.lastIndexOf(' ', limit - 1);
    if (split < 1) split = limit - 1;
    chunks.add(rest.substring(0, split + 1).trim());
    rest = rest.substring(split + 1).trim();
  }
  if (rest.isNotEmpty) chunks.add(rest);
  return chunks;
}
