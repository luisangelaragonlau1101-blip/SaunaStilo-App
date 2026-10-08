import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notificaciones_service.dart';

/// Delivery is a message in the project's existing, authorized conversation.
/// Only Administration can change the project's official status.
class ProjectClosureService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  ProjectClosureService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = firebaseAuth ?? FirebaseAuth.instance;

  Future<bool> save(
    String projectId,
    String operationId, {
    required bool approve,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión para continuar.');
    final project = db.collection('proyectos').doc(projectId);
    final event = project.collection('conversacion').doc('cierre_$operationId');
    Map<String, dynamic> data = {};
    await db.runTransaction((tx) async {
      final profile = await tx.get(db.collection('usuarios').doc(uid));
      final snapshot = await tx.get(project);
      final saved = await tx.get(event);
      final actor = profile.data();
      if (!profile.exists || actor?['activo'] == false)
        throw StateError('Tu cuenta no está activa.');
      if (!snapshot.exists) throw StateError('El proyecto ya no existe.');
      data = snapshot.data()!;
      final admin = actor?['rol'] == 'admin';
      if (approve && !admin)
        throw StateError('Solo Administración aprueba y finaliza proyectos.');
      if (!admin &&
          !(data['encargados'] is List &&
              (data['encargados'] as List).contains(uid))) {
        throw StateError('No estás asignado a este proyecto.');
      }
      if (saved.exists) {
        if (saved.data()?['autorId'] != uid ||
            saved.data()?['tipo'] !=
                (approve ? 'aprobacion_proyecto' : 'entrega_proyecto')) {
          throw StateError('Esta operación ya se guardó con otros datos.');
        }
        return;
      }
      if (['finalizado', 'completado'].contains(data['estatus']))
        throw StateError('El proyecto ya está finalizado.');
      tx.set(event, {
        'autorId': uid,
        'autorNombre': actor?['nombre'] ?? 'Integrante',
        'tipo': approve ? 'aprobacion_proyecto' : 'entrega_proyecto',
        'texto': approve
            ? 'Proyecto aprobado y finalizado por Administración.'
            : 'Proyecto marcado como terminado; entregado para aprobación de Administración.',
        'fecha': FieldValue.serverTimestamp(),
        'imagenes': <String>[],
        'likesPor': <String>[],
      });
      if (approve) {
        tx.update(project, {
          'estatus': 'finalizado',
          'aprobadoEn': FieldValue.serverTimestamp(),
          'aprobadoPor': uid,
          'revisionProyectoEn': FieldValue.serverTimestamp(),
        });
      }
    });
    final notifications = NotificacionesService(firestore: db);
    if (!approve) {
      return notifications.enviarEvento(
        id: 'proyecto_${event.id}',
        titulo: 'Proyecto por aprobar',
        mensaje: '${data['titulo'] ?? 'Proyecto'}',
        tipo: 'proyecto',
        rolesDestinatarios: const ['admin'],
        campos: {'proyectoId': projectId},
      );
    }
    var confirmed = true;
    for (final member
        in (data['encargados'] is List
            ? data['encargados'] as List
            : const [])) {
      final sent = await notifications.enviarEvento(
        id: 'proyecto_${event.id}_$member',
        titulo: 'Proyecto aprobado y finalizado',
        mensaje: '${data['titulo'] ?? 'Proyecto'}',
        tipo: 'proyecto',
        destinatarioId: member.toString(),
        campos: {'proyectoId': projectId},
      );
      confirmed = confirmed && sent;
    }
    return confirmed;
  }
}
