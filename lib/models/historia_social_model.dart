import 'package:cloud_firestore/cloud_firestore.dart';

class HistoriaSocialModel {
  final String id;
  final String autorId;
  final String autorNombre;
  final String autorFotoUrl;
  final String texto;
  final String imagenUrl;
  final String imagenRuta;
  final DateTime creadaEn;
  final DateTime expiraEn;

  const HistoriaSocialModel({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    required this.autorFotoUrl,
    required this.texto,
    required this.imagenUrl,
    required this.imagenRuta,
    required this.creadaEn,
    required this.expiraEn,
  });

  bool estaVigente(DateTime ahora) => expiraEn.isAfter(ahora);

  factory HistoriaSocialModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final creadaEn = _fecha(data['creadaEn']);
    final expiraEn = _fecha(data['expiraEn']);
    return HistoriaSocialModel(
      id: document.id,
      autorId: data['autorId']?.toString() ?? '',
      autorNombre: data['autorNombre']?.toString() ?? 'Equipo',
      autorFotoUrl: data['autorFotoUrl']?.toString() ?? '',
      texto: data['texto']?.toString() ?? '',
      imagenUrl: data['imagenUrl']?.toString() ?? '',
      imagenRuta: data['imagenRuta']?.toString() ?? '',
      creadaEn: creadaEn,
      expiraEn: expiraEn,
    );
  }

  static DateTime _fecha(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
