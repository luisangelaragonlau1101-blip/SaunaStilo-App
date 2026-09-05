import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notificacion_model.dart';

class NotificacionesService {
  final FirebaseFirestore _db;
  NotificacionesService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('notificaciones');

  Stream<List<NotificacionApp>> avisosPara({required String usuarioId, required String rol}) {
    return _ref.snapshots().map((snapshot) {
      final avisos = snapshot.docs.map(NotificacionApp.fromDocument).where((aviso) => aviso.visiblePara(usuarioId: usuarioId, rol: rol)).toList(growable: true);
      avisos.sort((a, b) => b.fecha.compareTo(a.fecha));
      return avisos;
    });
  }

  Stream<int> noLeidosPara({required String usuarioId, required String rol}) =>
      avisosPara(usuarioId: usuarioId, rol: rol).map((avisos) => avisos.where((aviso) => !aviso.leidaPor(usuarioId)).length);

  Future<void> marcarLeida(String avisoId, String usuarioId) async {
    await _ref.doc(avisoId).update({'leidosPor': FieldValue.arrayUnion([usuarioId])});
  }

  Future<void> marcarTodasLeidas({required String usuarioId, required String rol}) async {
    final snapshot = await _ref.get();
    final pendientes = snapshot.docs.map(NotificacionApp.fromDocument).where((aviso) => aviso.visiblePara(usuarioId: usuarioId, rol: rol) && !aviso.leidaPor(usuarioId)).toList(growable: false);
    const maximoPorLote = 400;
    for (var inicio = 0; inicio < pendientes.length; inicio += maximoPorLote) {
      final fin = inicio + maximoPorLote < pendientes.length ? inicio + maximoPorLote : pendientes.length;
      final batch = _db.batch();
      for (final aviso in pendientes.sublist(inicio, fin)) {
        batch.update(_ref.doc(aviso.id), {'leidosPor': FieldValue.arrayUnion([usuarioId])});
      }
      await batch.commit();
    }
  }

  Future<String> enviarAlertaGeneral({required String mensaje}) async {
    return _enviarCritica(mensaje: mensaje, llamada: false);
  }

  /// Crea una invitación crítica para TODO el equipo. El backend valida que
  /// `creadoPor` pertenezca a un administrador antes de enviar el push.
  Future<String> llamarATodoElEquipo({String mensaje = 'Administración solicita la atención inmediata de todo el equipo.'}) async {
    return _enviarCritica(mensaje: mensaje, llamada: true);
  }

  Future<String> _enviarCritica({required String mensaje, required bool llamada}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('Debes iniciar sesión como administrador.');
    final texto = mensaje.trim();
    if (texto.isEmpty) throw ArgumentError('Escribe el motivo de la alerta.');
    final ref = await _ref.add({
      'titulo': llamada ? '🚨 LLAMADA GENERAL · SAUNA STILO' : '🚨 ALERTA GENERAL · SAUNA STILO',
      'mensaje': texto.length > 420 ? texto.substring(0, 420) : texto,
      'tipo': 'alarma_admin',
      'destinatarioId': 'todos',
      'rolesDestinatarios': <String>['todos'],
      'leidosPor': <String>[],
      'creadoPor': uid,
      'fecha': FieldValue.serverTimestamp(),
      'prioridad': 'critica',
      'requiereAtencion': true,
      'esLlamada': llamada,
      'ruta': llamada ? 'mensajes' : 'avisos',
    });
    return ref.id;
  }

  static Map<String, dynamic> datosAviso({required String titulo, required String mensaje, required String tipo, String destinatarioId = '', List<String> rolesDestinatarios = const <String>[]}) {
    return {
      'titulo': titulo.trim(), 'mensaje': mensaje.trim(), 'tipo': tipo,
      'destinatarioId': destinatarioId, 'rolesDestinatarios': rolesDestinatarios,
      'leidosPor': <String>[], 'creadoPor': FirebaseAuth.instance.currentUser?.uid ?? '',
      'fecha': FieldValue.serverTimestamp(),
    };
  }
}
