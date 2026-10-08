import 'package:flutter/material.dart';

/// Actions stay visible on cards and above evidence in the detail.
class TaskActionBar extends StatelessWidget {
  final String status;
  final bool admin, responsible, enabled;
  final VoidCallback onComplete, onApprove;
  const TaskActionBar({
    super.key,
    required this.status,
    required this.admin,
    required this.responsible,
    this.enabled = true,
    required this.onComplete,
    required this.onApprove,
  });
  @override
  Widget build(BuildContext context) {
    if (status == 'completado') return const SizedBox.shrink();
    if (status == 'en_revision') {
      return admin
          ? FilledButton.icon(
              onPressed: enabled ? onApprove : null,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Aprobar y finalizar'),
            )
          : const Text('Entregada · pendiente de aprobación');
    }
    if (!admin && !responsible) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: enabled ? onComplete : null,
      icon: const Icon(Icons.task_alt),
      label: const Text('Marcar como terminada'),
    );
  }
}
