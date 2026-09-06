import 'package:flutter/material.dart';
import 'stilo_orbit.dart';

/// Choosing a general task never queries projects. Project permissions stay separate.
class TaskCreationChoice extends StatelessWidget {
  final bool admin;
  final VoidCallback onGeneral, onProject;
  const TaskCreationChoice({super.key, required this.admin, required this.onGeneral, required this.onProject});
  @override
  Widget build(BuildContext context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('¿Qué necesitas asignar?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(admin ? 'Elige una tarea diaria o vincúlala a un proyecto. No necesitas crear un proyecto para organizar el trabajo del día.' : 'Puedes asignar actividades a los integrantes de los proyectos que tienes a cargo.', style: const TextStyle(color: Colors.white60, height: 1.4)),
      const SizedBox(height: 22),
      if (admin) ...[
        _option('Tarea general', 'Asignar a una persona · sin proyecto', Icons.checklist_rounded, stiloAccents[0], onGeneral),
        const SizedBox(height: 12),
      ],
      _option('Tarea de un proyecto', 'Elegir proyecto y responsable', Icons.folder_open_rounded, stiloAccents[2], onProject),
      const SizedBox(height: 10),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
    ])));
  Widget _option(String title, String subtitle, IconData icon, Color color, VoidCallback action) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: BorderSide(color: color.withOpacity(.35))),
    child: InkWell(borderRadius: BorderRadius.circular(26), onTap: action, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      StiloOrbitIcon(icon: icon, color: color), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13))])),
      const Icon(Icons.chevron_right_rounded),
    ]))),
  );
}
