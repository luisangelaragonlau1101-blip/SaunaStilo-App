import 'package:flutter/material.dart';

String workStatusLabel(String? status) => switch (status) {
  'en_progreso' => 'En progreso',
  'en_revision' => 'Por aprobar',
  'cambios_solicitados' => 'Requiere cambios',
  'completado' => 'Aprobada y finalizada',
  _ => 'Pendiente',
};
String workKindLabel(String? kind) => switch (kind) {
  'extra' => 'Tarea extra', 'instalacion' => 'Instalación', 'envio' => 'Envío', _ => 'Tarea del día',
};
Color workStatusColor(String? status) => switch (status) {
  'completado' => const Color(0xFF72CCA4),
  'en_revision' => const Color(0xFFE8B35F),
  'cambios_solicitados' => const Color(0xFFFF7E91),
  _ => const Color(0xFFBEA1DF),
};
class WorkStatus extends StatelessWidget {
  final String? status;
  const WorkStatus(this.status, {super.key});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(color: workStatusColor(status).withValues(alpha: .13), borderRadius: BorderRadius.circular(12)),
    child: Text(workStatusLabel(status), style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Theme.of(context).colorScheme.onSurface : workStatusColor(status), fontSize: 12, fontWeight: FontWeight.w700)),
  );
}
