import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/jornada_pause.dart';

class JornadaPauseHistory extends StatelessWidget {
  final List<JornadaPause> pauses;
  final bool expandable;
  const JornadaPauseHistory({super.key, required this.pauses, this.expandable = false});
  String _hour(DateTime? date) => date == null ? '—'
      : DateFormat('HH:mm').format(date.toUtc().subtract(const Duration(hours: 6)));
  @override
  Widget build(BuildContext context) {
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final pause in pauses) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(pause.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('Salida ${_hour(pause.departure)} · Regreso ${_hour(pause.returned)}${pause.minutes == null ? ' · Sin regreso registrado' : ' · ${pause.minutes} min'}'),
        if (pause.detail.isNotEmpty) Text(pause.detail),
      ])),
    ]);
    if (pauses.isEmpty) return const SizedBox.shrink();
    return expandable ? ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Pausas y salidas (${pauses.length})'), children: [content]) : content;
  }
}
