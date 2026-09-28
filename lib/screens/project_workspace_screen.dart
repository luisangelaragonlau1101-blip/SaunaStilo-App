import '../presentation/appearance.dart';
import 'crear_proyecto_admin_screen.dart';
import 'editar_proyecto_admin_screen.dart';
import '../widgets/project_progress_card.dart';
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
  final bool embedded;
  const ProjectWorkspaceScreen({super.key, required this.usuario, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final admin = usuario.rol == AppRoles.admin;
    final query = admin ? FirebaseFirestore.instance.collection('proyectos') : FirebaseFirestore.instance.collection('proyectos').where('encargados', arrayContains: usuario.id);
    return Scaffold(backgroundColor: StiloColors.background, appBar: embedded ? null : AppBar(title: Text('Proyectos y grupos'), actions: [
      if (admin) IconButton(tooltip: 'Administrar proyectos', icon: Icon(Icons.tune_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => admin ? ProyectosAdminScreen() : ProyectosTrabajadorScreen(esMaestro: usuario.rol == AppRoles.maestro)))),
    ]), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(includeMetadataChanges: true), builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No se pudieron consultar tus proyectos. Revisa Internet y los permisos de tu cuenta.')));
      if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
      final projects = snapshot.data!.docs.map(Proyecto.fromFirestore).toList();
      return ListView(padding: EdgeInsets.all(18), children: [
        if (admin) Padding(padding: EdgeInsets.only(bottom: 16), child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CrearProyectoAdminScreen())), icon: Icon(Icons.group_add_outlined), label: Text('Crear proyecto y su grupo'))),
        OfflineDataBadge(cached: snapshot.data!.metadata.isFromCache),
        Container(padding: EdgeInsets.all(18), decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: StiloColors.border)), child: Text('Cada proyecto tiene su propio grupo. Aquí se reúnen sus fotografías, audios, comentarios y evidencias; no necesitas crear un chat duplicado.', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.4))),
        SizedBox(height: 16),
        if (projects.isEmpty) Padding(padding: EdgeInsets.all(24), child: Text('Aún no tienes proyectos asignados. Administración puede añadirte al equipo de un proyecto.')),
        for (final project in projects) Card(color: StiloColors.surface, margin: EdgeInsets.only(bottom: 14), child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.workspaces_outline, color: StiloColors.accent), SizedBox(width: 10), Expanded(child: Text(project.titulo, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)))]),
          SizedBox(height: 14),
          ProjectProgressCard(projectId: project.id),
          SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(icon: Icon(Icons.forum_outlined), label: Text('Grupo y evidencias'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProyectoChatScreen(proyecto: project)))),
            if (admin) OutlinedButton.icon(icon: Icon(Icons.manage_accounts_outlined), label: Text('Administrar integrantes'), onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EditarProyectoAdminScreen(proyecto: project)))),
            if (admin || usuario.rol == AppRoles.maestro) OutlinedButton.icon(icon: Icon(Icons.add_task_rounded), label: Text('Asignar actividad'), onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => ModalAsignarActividad(proyectoId: project.id, rolUsuario: usuario.rol))),
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
