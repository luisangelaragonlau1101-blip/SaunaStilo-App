import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionApp {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final String destinatarioId;
  final List<String> rolesDestinatarios;
  final List<String> leidosPor;
  final DateTime fecha;

  const NotificacionApp({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.destinatarioId,
    required this.rolesDestinatarios,
    required this.leidosPor,
    required this.fecha,
  });

  bool visiblePara({required String usuarioId, required String rol}) {
    return destinatarioId == usuarioId ||
        destinatarioId == 'todos' ||
        rolesDestinatarios.contains(rol) ||
        rolesDestinatarios.contains('todos');
  }

  bool leidaPor(String usuarioId) => leidosPor.contains(usuarioId);

  factory NotificacionApp.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final fechaRaw = data['fecha'];
    return NotificacionApp(
      id: doc.id,
      titulo: data['titulo']?.toString() ?? 'Aviso',
      mensaje: data['mensaje']?.toString() ?? '',
      tipo: data['tipo']?.toString() ?? 'general',
      destinatarioId: data['destinatarioId']?.toString() ?? '',
      rolesDestinatarios: (data['rolesDestinatarios'] is Iterable)
          ? (data['rolesDestinatarios'] as Iterable)
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      leidosPor: (data['leidosPor'] is Iterable)
          ? (data['leidosPor'] as Iterable)
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      fecha: fechaRaw is Timestamp ? fechaRaw.toDate() : DateTime.now(),
    );
  }
}
