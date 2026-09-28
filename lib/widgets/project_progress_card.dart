import '../presentation/appearance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../workflow/staff_policy.dart';

class ProjectProgressCard extends StatelessWidget {
  final String projectId;
  const ProjectProgressCard({super.key, required this.projectId});
  @override Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('actividades').where('proyectoId', isEqualTo: projectId).snapshots(includeMetadataChanges: true),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Padding(padding: EdgeInsets.all(10), child: Text('No se pudo calcular el avance. Revisa los permisos del proyecto.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)));
      if (!snapshot.hasData) return LinearProgressIndicator();
      final tasks = snapshot.data!.docs, states = tasks.map((t) => t.data()['estatus']?.toString() ?? 'pendiente');
      final done = states.where((s) => s == 'completado').length, percent = projectCompletion(states);
      return Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(Icons.trending_up_rounded, color: StiloColors.accent), SizedBox(width: 8), Expanded(child: Text('$done de ${tasks.length} tareas completadas', style: TextStyle(fontWeight: FontWeight.w700))), Text('$percent%', style: TextStyle(fontSize: 22, color: StiloColors.accent, fontWeight: FontWeight.w900))]),
        SizedBox(height: 10), LinearProgressIndicator(value: percent / 100, borderRadius: BorderRadius.circular(10)),
        SizedBox(height: 7), Text(snapshot.data!.metadata.hasPendingWrites ? 'Avance local: pendiente de confirmación del servidor.' : snapshot.data!.metadata.isFromCache ? 'Último avance guardado; sin actualización del servidor.' : tasks.isEmpty ? 'Asigna tareas para comenzar a medir el proyecto.' : 'Calculado con las tareas del proyecto. El trabajo extra no altera este porcentaje.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60), fontSize: 11)),
      ]));
    });
}
