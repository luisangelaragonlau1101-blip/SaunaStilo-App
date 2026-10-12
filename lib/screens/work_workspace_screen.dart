import '../presentation/appearance.dart';
import 'admin_team_progress_screen.dart';
import '../presentation/modern_workspace.dart';
import 'extra_work_screen.dart';
import 'notification_health_screen.dart';
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
  Map<int, String> get sections => {0:'Del día', 1:'Extras', 2:'Actividades', 3:'Proyectos', 4:'Instalaciones y envíos', if (widget.usuario.rol == AppRoles.admin) 5:'Equipo'};
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proyectos y tareas'), actions: [if (widget.usuario.rol == AppRoles.admin) IconButton(tooltip: 'Ver avances de todo el equipo', onPressed: () => setState(() => section = 5), icon: const Icon(Icons.insights_rounded)), IconButton(tooltip: 'Activar notificaciones de trabajo', onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => NotificationHealthScreen(user: widget.usuario))), icon: const Icon(Icons.notifications_active_outlined)), IconButton(tooltip: 'Reportar trabajo extra ya realizado', onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExtraWorkScreen(user: widget.usuario))), icon: const Icon(Icons.add_task_outlined))]),
    body: Column(children: [
      if (AppearanceController.instance.modern) WorkspaceTabs(items: sections, selected: section, onSelected: (i) => setState(() => section = i))
      else SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
        for (final entry in sections.entries)
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(entry.value), selected: section == entry.key, onSelected: (_) => setState(() => section = entry.key))),
      ])),
      Expanded(child: switch (section) {
        5 when widget.usuario.rol == AppRoles.admin => AdminTeamProgressScreen(user: widget.usuario, embedded: true),
        1 => DailyTasksScreen(key: const ValueKey('extras'), user: widget.usuario, embedded: true, kind: 'extra'),
        2 => ProjectActivitiesScreen(usuario: widget.usuario, embedded: true),
        3 => ProjectWorkspaceScreen(usuario: widget.usuario, embedded: true),
        4 => DailyTasksScreen(key: const ValueKey('operations'), user: widget.usuario, embedded: true, operations: true),
        _ => DailyTasksScreen(key: const ValueKey('daily'), user: widget.usuario, embedded: true),
      }),
    ]),
  );
}
