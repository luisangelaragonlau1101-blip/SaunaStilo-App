import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../screens/mensajes_equipo_screen.dart';
import '../screens/proyecto_chat_screen.dart';
import '../screens/equipo_tareas_screen.dart';
import '../screens/jornada_screen.dart';

class NotificationRouter {
  static Future<void> open(BuildContext context, UserModel user, String id) async {
    try {
      final db = FirebaseFirestore.instance;
      final record = await db.collection('notificaciones').doc(id).get();
      if (!record.exists || !context.mounted) return;
      final data = record.data()!;
      final recipient = data['destinatarioId'];
      final roles = List<String>.from(data['rolesDestinatarios'] ?? const []);
      if (recipient != user.id && recipient != 'todos' && !roles.contains('todos') && !roles.contains(user.rol)) throw StateError('Aviso no autorizado.');
      Widget destination = MensajesEquipoScreen(usuario: user);
      final conversationId = data['conversacionId']?.toString() ?? '';
      final projectId = data['proyectoId']?.toString() ?? '';
      if (conversationId.isNotEmpty) {
        final conversation = await db.collection('conversaciones').doc(conversationId).get();
        final members = List<String>.from(conversation.data()?['participantes'] ?? const []);
        if (members.length != 2 || !members.contains(user.id)) throw StateError('Chat no autorizado.');
        final contact = await db.collection('usuarios').doc(members.firstWhere((m) => m != user.id)).get();
        if (!contact.exists) throw StateError('La cuenta de contacto ya no existe.');
        destination = ConversacionPrivadaScreen(usuario: user, contacto: UserModel.fromFirestore(contact));
      } else if (data['tipo'] == 'tarea') {
        destination = EquipoTareasScreen(usuario: user);
      } else if (projectId.isNotEmpty) {
        final project = await db.collection('proyectos').doc(projectId).get();
        if (!project.exists) throw StateError('El proyecto ya no existe.');
        final model = Proyecto.fromFirestore(project);
        if (user.rol != AppRoles.admin && !model.encargados.contains(user.id)) throw StateError('No perteneces a este proyecto.');
        destination = ProyectoChatScreen(proyecto: model);
      } else if ((data['tipo']?.toString() ?? '').startsWith('asistencia_')) {
        destination = JornadaScreen(usuario: user);
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => destination));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir este aviso. Revisa tu conexión y acceso al proyecto o chat.')));
    }
  }
}
