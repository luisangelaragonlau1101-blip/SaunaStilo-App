import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/offline_workspace.dart';
import '../widgets/project_picker.dart';
import '../widgets/project_progress_card.dart';
import '../workflow/staff_policy.dart';
import 'daily_tasks_screen.dart';
import 'modal_asignar_actividades.dart';

export 'work_workspace_screen.dart' show EquipoTareasScreen;

/// Project filtering uses the same activity cards and delivery flow as Home.
/// An activity is never copied merely because it appears in another workspace.
class ProjectActivitiesScreen extends StatefulWidget {
  final UserModel usuario;
  final bool embedded;
  final String? initialProjectId, initialProjectTitle;
  const ProjectActivitiesScreen({
    super.key,
    required this.usuario,
    this.embedded = false,
    this.initialProjectId,
    this.initialProjectTitle,
  });
  @override
  State<ProjectActivitiesScreen> createState() => _ProjectActivitiesState();
}

class _ProjectActivitiesState extends State<ProjectActivitiesScreen> {
  late String? _projectId = widget.initialProjectId;
  late String _projectTitle =
      widget.initialProjectTitle ?? 'Todos mis proyectos';
  int _revision = 0;
  Future<void> _selectProject({bool create = false}) async {
    final project = await elegirProyecto(
      context,
      widget.usuario,
      titulo: create
          ? 'Proyecto para la nueva actividad'
          : 'Actividades de un proyecto',
    );
    if (project == null || !mounted) return;
    setState(() {
      _projectId = project.id;
      _projectTitle = project.titulo;
    });
    if (create) await _create();
  }

  Future<void> _create() async {
    if (_projectId == null) {
      await _selectProject(create: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalAsignarActividad(
        proyectoId: _projectId!,
        rolUsuario: widget.usuario.rol,
      ),
    );
    if (mounted) setState(() => _revision++);
  }

  @override
  void didUpdateWidget(covariant ProjectActivitiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.id != widget.usuario.id ||
        oldWidget.usuario.rol != widget.usuario.rol) {
      _projectId = null;
      _projectTitle = 'Todos mis proyectos';
      _revision++;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(title: const Text('Actividades por proyecto')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(_projectTitle),
                onPressed: _selectProject,
              ),
              if (_projectId != null)
                ActionChip(
                  label: const Text('Ver todas mis actividades'),
                  onPressed: () => setState(() {
                    _projectId = null;
                    _projectTitle = 'Todos mis proyectos';
                  }),
                ),
            ],
          ),
        ),
        if (canAssignWork(widget.usuario.rol))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Asignar actividad de proyecto'),
              ),
            ),
          ),
        if (_projectId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: ProjectProgressCard(projectId: _projectId!),
          ),
        Expanded(
          child: DailyTasksScreen(
            key: ValueKey('$_projectId:$_revision:${widget.usuario.id}'),
            user: widget.usuario,
            embedded: true,
            kind: 'all',
            projectId: _projectId,
            allDates: true,
            showCreate: false,
          ),
        ),
      ],
    ),
  );
}
