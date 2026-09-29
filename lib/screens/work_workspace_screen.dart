import 'extra_work_screen.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'daily_tasks_screen.dart';
import 'equipo_tareas_screen.dart';
import 'project_workspace_screen.dart';

class EquipoTareasScreen extends StatefulWidget {
  final UserModel usuario;
  final int initialSection;
  const EquipoTareasScreen({super.key, required this.usuario, this.initialSection = 0});
  @override State<EquipoTareasScreen> createState() => _WorkState();
}
class _WorkState extends State<EquipoTareasScreen> {
  late int section = widget.initialSection;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proyectos y tareas'), actions: [IconButton(tooltip: 'Reportar trabajo extra ya realizado', onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExtraWorkScreen(user: widget.usuario))), icon: const Icon(Icons.add_task_outlined))]),
    body: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
        for (final entry in {0:'Del día', 1:'Extras', 2:'Actividades', 3:'Proyectos', 4:'Instalaciones y envíos'}.entries)
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(entry.value), selected: section == entry.key, onSelected: (_) => setState(() => section = entry.key))),
      ])),
      Expanded(child: switch (section) {
        1 => DailyTasksScreen(key: const ValueKey('extras'), user: widget.usuario, embedded: true, kind: 'extra'),
        2 => ProjectActivitiesScreen(usuario: widget.usuario, embedded: true),
        3 => ProjectWorkspaceScreen(usuario: widget.usuario, embedded: true),
        4 => DailyTasksScreen(key: const ValueKey('operations'), user: widget.usuario, embedded: true, operations: true),
        _ => DailyTasksScreen(key: const ValueKey('daily'), user: widget.usuario, embedded: true),
      }),
    ]),
  );
}
