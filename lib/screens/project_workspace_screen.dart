import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/offline_workspace.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';
import '../models/actividad_model.dart';
import '../services/actividades_service.dart';
import 'proyecto_chat_screen.dart';
import 'proyectos_admin_screen.dart';
import 'proyectos_trabajador_screen.dart';
import 'modal_asignar_actividades.dart';

class ProjectWorkspaceScreen extends StatelessWidget {
  final UserModel usuario;
  const ProjectWorkspaceScreen({super.key, required this.usuario});
  @override
  Widget build(BuildContext context) {
    final admin = usuario.rol == AppRoles.admin;
    final query = admin ? FirebaseFirestore.instance.collection('proyectos') : FirebaseFirestore.instance.collection('proyectos').where('encargados', arrayContains: usuario.id);
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Proyectos y grupos'), actions: [
      IconButton(tooltip: 'Administrar proyectos', icon: const Icon(Icons.tune_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => admin ? const ProyectosAdminScreen() : ProyectosTrabajadorScreen(esMaestro: usuario.rol == AppRoles.maestro)))),
    ]), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(includeMetadataChanges: true), builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No se pudieron consultar tus proyectos. Revisa Internet y los permisos de tu cuenta.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final projects = snapshot.data!.docs.map(Proyecto.fromFirestore).toList();
      return ListView(padding: const EdgeInsets.all(18), children: [
        OfflineDataBadge(cached: snapshot.data!.metadata.isFromCache),
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF180C11), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF68243B))), child: const Text('Cada proyecto tiene su propio grupo. Aquí se reúnen sus fotografías, audios, comentarios y evidencias; no necesitas crear un chat duplicado.', style: TextStyle(color: Colors.white70, height: 1.4))),
        const SizedBox(height: 16),
        if (projects.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aún no tienes proyectos asignados. Administración puede añadirte al equipo de un proyecto.')),
        for (final project in projects) Card(color: const Color(0xFF111012), margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.workspaces_outline, color: Color(0xFFB7FF2A)), const SizedBox(width: 10), Expanded(child: Text(project.titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)))]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(icon: const Icon(Icons.forum_outlined), label: const Text('Grupo y evidencias'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProyectoChatScreen(proyecto: project)))),
            if (admin || usuario.rol == AppRoles.maestro) OutlinedButton.icon(icon: const Icon(Icons.add_task_rounded), label: const Text('Asignar actividad'), onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => ModalAsignarActividad(proyectoId: project.id, rolUsuario: usuario.rol))),
          ]),
        ]))),
      ]);
    }));
  }
}

class ProjectTaskComposer extends StatelessWidget {
  final UserModel usuario;
  final Proyecto proyecto;
  const ProjectTaskComposer({super.key, required this.usuario, required this.proyecto});
  @override
  Widget build(BuildContext context) => ModalAsignarActividad(proyectoId: proyecto.id, rolUsuario: usuario.rol);
}
