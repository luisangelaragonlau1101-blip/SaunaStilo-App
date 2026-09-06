import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'notificaciones_service.dart';

class TeamContactService {
  final FirebaseFirestore db;
  TeamContactService({FirebaseFirestore? firestore}) : db = firestore ?? FirebaseFirestore.instance;
  String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return 'privado_${ids.join('_')}';
  }
  DocumentReference<Map<String, dynamic>> conversation(UserModel user, UserModel contact) => db.collection('conversaciones').doc(conversationId(user.id, contact.id));

  Future<void> ensureConversation(UserModel user, UserModel contact, {bool forSending = false}) async {
    if (FirebaseAuth.instance.currentUser?.uid != user.id || user.id == contact.id) throw StateError('Inicia sesión con tu cuenta y selecciona otro integrante.');
    final ref = conversation(user, contact);
    try {
      final snapshot = await ref.get(GetOptions(source: forSending ? Source.server : Source.serverAndCache)).timeout(const Duration(seconds: 15));
      if (snapshot.exists) {
        final members = List<String>.from(snapshot.data()?['participantes'] ?? const []);
        if (members.length != 2 || !members.contains(user.id) || !members.contains(contact.id)) throw StateError('No tienes acceso a esta conversación.');
        return; // Preserve legacy member order: security rules require it to remain unchanged.
      }
    } on FirebaseException catch (error) {
      // Reading a nonexistent protected document may be denied. The create below
      // still passes Firestore rules and cannot overwrite another private group.
      if (error.code != 'permission-denied' && error.code != 'not-found') rethrow;
    }
    final members = [user.id, contact.id]..sort();
    await ref.set({
      'participantes': members,
      'nombres': {user.id: user.nombre, contact.id: contact.nombre},
      'actualizadaEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> saveMessage({required UserModel user, required UserModel contact, required String messageId, required Map<String, dynamic> data, bool onScreen = true, bool call = false, bool toolRequest = false}) async {
    await ensureConversation(user, contact, forSending: true);
    final ref = conversation(user, contact);
    final batch = db.batch();
    batch.set(ref.collection('mensajes').doc(messageId), {
      ...data,
      'autorId': user.id, 'autorNombre': user.nombre,
      'fecha': FieldValue.serverTimestamp(),
    });
    batch.update(ref, {'actualizadaEn': FieldValue.serverTimestamp(), 'ultimoMensaje': call ? 'Invitación a llamada' : 'Nuevo mensaje'});
    await batch.commit();
    // A notification failure must never turn an already saved message into a
    // failed send, erase its attachments, or cause a duplicate on retry.
    try {
      await db.collection('notificaciones').doc('privado_$messageId').set(
        NotificacionesService.datosAviso(
          titulo: call ? '${user.nombre} te llama' : toolRequest ? '${user.nombre} solicita herramienta' : 'Mensaje de ${user.nombre}',
          mensaje: call ? 'Abre el chat para entrar a la llamada.' : 'Abre tu conversación para leer el mensaje privado.',
          tipo: onScreen ? 'aviso_personal' : 'mensaje_privado',
          destinatarioId: contact.id,
        )..addAll({'conversacionId': ref.id, 'mensajeId': messageId, 'esLlamada': call, 'ruta': '/mensajes'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
