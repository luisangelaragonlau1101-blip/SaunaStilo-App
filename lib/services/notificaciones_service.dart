import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notificacion_model.dart';

class NotificacionesService {
  final FirebaseFirestore _db;

  NotificacionesService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('notificaciones');

  Stream<List<NotificacionApp>> avisosPara({
    required String usuarioId,
    required String rol,
  }) {
    return _ref.snapshots().map((snapshot) {
      final avisos = snapshot.docs
          .map(NotificacionApp.fromDocument)
          .where(
            (aviso) => aviso.visiblePara(usuarioId: usuarioId, rol: rol),
          )
          .toList(growable: true);
      avisos.sort((a, b) => b.fecha.compareTo(a.fecha));
      return avisos;
    });
  }

  Stream<int> noLeidosPara({
    required String usuarioId,
    required String rol,
  }) {
    return avisosPara(usuarioId: usuarioId, rol: rol).map(
      (avisos) => avisos.where((aviso) => !aviso.leidaPor(usuarioId)).length,
    );
  }

  Future<void> marcarLeida(String avisoId, String usuarioId) async {
    await _ref.doc(avisoId).update({
      'leidosPor': FieldValue.arrayUnion([usuarioId]),
    });
  }

  Future<void> marcarTodasLeidas({
    required String usuarioId,
    required String rol,
  }) async {
    final snapshot = await _ref.get();
    final pendientes = snapshot.docs
        .map(NotificacionApp.fromDocument)
        .where(
          (aviso) =>
              aviso.visiblePara(usuarioId: usuarioId, rol: rol) &&
              !aviso.leidaPor(usuarioId),
        )
        .toList(growable: false);
    const maximoPorLote = 400;
    for (var inicio = 0; inicio < pendientes.length; inicio += maximoPorLote) {
      final fin = (inicio + maximoPorLote < pendientes.length)
          ? inicio + maximoPorLote
          : pendientes.length;
      final batch = _db.batch();
      for (final aviso in pendientes.sublist(inicio, fin)) {
        batch.update(_ref.doc(aviso.id), {
          'leidosPor': FieldValue.arrayUnion([usuarioId]),
        });
      }
      await batch.commit();
    }
  }

  static Map<String, dynamic> datosAviso({
    required String titulo,
    required String mensaje,
    required String tipo,
    String destinatarioId = '',
    List<String> rolesDestinatarios = const <String>[],
  }) {
    return {
      'titulo': titulo.trim(),
      'mensaje': mensaje.trim(),
      'tipo': tipo,
      'destinatarioId': destinatarioId,
      'rolesDestinatarios': rolesDestinatarios,
      'leidosPor': <String>[],
      'fecha': FieldValue.serverTimestamp(),
    };
  }
}
