import '../presentation/appearance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/proyecto_model.dart';
import '../models/user_model.dart';

Future<Proyecto?> elegirProyecto(
  BuildContext context,
  UserModel usuario, {
  String titulo = 'Elige un proyecto',
}) {
  final db = FirebaseFirestore.instance;
  final Query<Map<String, dynamic>> query = usuario.rol == AppRoles.admin
      ? db.collection('proyectos')
      : db
            .collection('proyectos')
            .where('encargados', arrayContains: usuario.id);
  return showModalBottomSheet<Proyecto>(
    context: context,
    isScrollControlled: true,
    backgroundColor: StiloColors.surface,
    builder: (context) => ProjectPickerSheet(
      query: query,
      titulo: titulo,
      admin: usuario.rol == AppRoles.admin,
    ),
  );
}

class ProjectPickerSheet extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final String titulo;
  final bool admin;
  const ProjectPickerSheet({
    required this.query,
    required this.titulo,
    required this.admin,
  });
  @override
  State<ProjectPickerSheet> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends State<ProjectPickerSheet> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _projects = widget.query
      .snapshots(includeMetadataChanges: true);
  void _retry() => setState(
    () => _projects = widget.query.snapshots(includeMetadataChanges: true),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _projects,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final error = snapshot.error;
          final denied =
              error is FirebaseException && error.code == 'permission-denied';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Solo aparecen los proyectos permitidos para tu cuenta.',
                style: TextStyle(
                  color: StiloColors.text.withValues(alpha: .60),
                ),
              ),
              const SizedBox(height: 24),
              if (snapshot.hasError) ...[
                Text(
                  denied
                      ? 'El servidor bloqueó la lista de proyectos. Administración debe actualizar los permisos de proyectos.'
                      : 'No se pudieron cargar los proyectos. Revisa tu conexión y vuelve a intentarlo.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ] else if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (docs.isEmpty) ...[
                Icon(
                  Icons.folder_off_outlined,
                  size: 40,
                  color: StiloColors.text.withValues(alpha: .38),
                ),
                const SizedBox(height: 15),
                Text(
                  snapshot.data!.metadata.isFromCache
                      ? 'No hay proyectos descargados. Conecta a Internet para consultar la lista actual.'
                      : widget.admin
                      ? 'No hay proyectos registrados todavía. Para organizar el trabajo diario, vuelve y elige Tarea general.'
                      : 'Todavía no tienes proyectos asignados. Administración debe agregarte a los proyectos que tienes a cargo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ] else
                for (final doc in docs)
                  ListTile(
                    leading: const Icon(Icons.folder_shared_outlined),
                    title: Text(Proyecto.fromFirestore(doc).titulo),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pop(context, Proyecto.fromFirestore(doc)),
                  ),
            ],
          );
        },
      ),
    ),
  );
}
