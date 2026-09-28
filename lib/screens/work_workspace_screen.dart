import 'extra_work_screen.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'daily_tasks_screen.dart';
import 'equipo_tareas_screen.dart';
import 'project_workspace_screen.dart';

class EquipoTareasScreen extends StatefulWidget {
  final UserModel usuario;
  const EquipoTareasScreen({super.key, required this.usuario});
  @override State<EquipoTareasScreen> createState() => _WorkState();
}
class _WorkState extends State<EquipoTareasScreen> {
  int section = 0;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proyectos y tareas'), actions: [IconButton(tooltip: 'Reportar trabajo extra', onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExtraWorkScreen(user: widget.usuario))), icon: const Icon(Icons.add_task_outlined))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: SizedBox(width: double.infinity, child: SegmentedButton<int>(segments: const [
        ButtonSegment(value: 0, label: Text('Actividades'), icon: Icon(Icons.checklist)),
        ButtonSegment(value: 1, label: Text('Del día'), icon: Icon(Icons.today)),
        ButtonSegment(value: 2, label: Text('Proyectos'), icon: Icon(Icons.workspaces_outline)),
      ], selected: {section}, showSelectedIcon: false, onSelectionChanged: (v) => setState(() => section = v.first)))),
      Expanded(child: switch (section) {
        1 => DailyTasksScreen(user: widget.usuario, embedded: true),
        2 => ProjectWorkspaceScreen(usuario: widget.usuario, embedded: true),
        _ => ProjectActivitiesScreen(usuario: widget.usuario, embedded: true),
      }),
    ]),
  );
}
