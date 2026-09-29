import 'package:cloud_firestore/cloud_firestore.dart';

const jornadaPauseTypes = <String, String>{
  'bano': 'Baño',
  'trabajo': 'Encargo de trabajo',
  'personal': 'Salida personal',
  'otro': 'Otro motivo',
};

class JornadaPause {
  final String id, type, detail;
  final DateTime? departure, returned;
  const JornadaPause({required this.id, required this.type, this.detail = '', this.departure, this.returned});

  static DateTime? _date(dynamic value) => value is Timestamp
      ? value.toDate() : value is String ? DateTime.tryParse(value) : null;
  factory JornadaPause.fromData(Map<String, dynamic> data) => JornadaPause(
    id: data['id']?.toString() ?? '',
    type: data['tipo']?.toString() ?? 'otro',
    detail: data['descripcion']?.toString() ?? '',
    departure: _date(data['salida']),
    returned: _date(data['regreso']),
  );
  String get label => jornadaPauseTypes[type] ?? 'Otro motivo';
  int? get minutes => departure != null && returned != null && !returned!.isBefore(departure!)
      ? returned!.difference(departure!).inMinutes : null;
  static List<JornadaPause> parse(dynamic value) => value is List
      ? value.whereType<Map>().map((p) => JornadaPause.fromData(Map<String, dynamic>.from(p))).toList() : [];
}
