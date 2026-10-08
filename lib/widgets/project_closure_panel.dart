import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/project_closure_service.dart';

class ProjectClosureActions extends StatelessWidget {
  final bool admin, assigned, closed, delivered, enabled;
  final VoidCallback onComplete, onApprove;
  const ProjectClosureActions({
    super.key,
    required this.admin,
    required this.assigned,
    required this.closed,
    required this.delivered,
    this.enabled = true,
    required this.onComplete,
    required this.onApprove,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        closed
            ? 'Proyecto aprobado y finalizado'
            : delivered
            ? 'Proyecto terminado · por aprobar'
            : 'Entrega y cierre del proyecto',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (!closed && (admin || assigned)) ...[
        const SizedBox(height: 8),
        if (!delivered)
          OutlinedButton.icon(
            onPressed: enabled ? onComplete : null,
            icon: const Icon(Icons.task_alt),
            label: const Text('Marcar proyecto como terminado'),
          ),
        if (admin)
          FilledButton.icon(
            onPressed: enabled ? onApprove : null,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Aprobar y finalizar proyecto'),
          ),
        Text(
          admin
              ? 'El cierre del proyecto conserva las tareas y sus revisiones individuales.'
              : 'Administración revisará la entrega antes de finalizar el proyecto.',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ],
  );
}

class ProjectClosurePanel extends StatefulWidget {
  final String projectId;
  const ProjectClosurePanel({super.key, required this.projectId});
  @override
  State<ProjectClosurePanel> createState() => _ProjectClosureState();
}

class _ProjectClosureState extends State<ProjectClosurePanel> {
  final _service = ProjectClosureService();
  late final _project = _service.db
      .collection('proyectos')
      .doc(widget.projectId)
      .snapshots(includeMetadataChanges: true);
  late final _deliveries = _service.db
      .collection('proyectos')
      .doc(widget.projectId)
      .collection('conversacion')
      .where('tipo', isEqualTo: 'entrega_proyecto')
      .snapshots();
  late final _profile = _service.db
      .collection('usuarios')
      .doc(FirebaseAuth.instance.currentUser?.uid ?? '_sin_sesion')
      .snapshots(includeMetadataChanges: true);
  bool _busy = false;
  String? _error, _operation;
  bool? _lastApprove;
  Future<void> _save(bool approve) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          approve
              ? '¿Aprobar y finalizar el proyecto?'
              : '¿Terminaste el proyecto?',
        ),
        content: Text(
          approve
              ? 'El proyecto quedará finalizado. Sus tareas conservarán su estado y se revisan por separado.'
              : 'La entrega se registrará en el grupo del proyecto y Administración podrá aprobarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(approve ? 'Aprobar y finalizar' : 'Entregar proyecto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_lastApprove != approve || _operation == null) {
      _lastApprove = approve;
      _operation = _service.db.collection('proyectos').doc().id;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await _service.save(
        widget.projectId,
        _operation!,
        approve: approve,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sent
                  ? approve
                        ? 'Proyecto aprobado y finalizado.'
                        : 'Proyecto entregado para aprobación.'
                  : 'Cambio guardado. No se confirmó el aviso al equipo.',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'No se confirmó el cambio. Revisa tu conexión e intenta de nuevo.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profile,
        builder: (context, actor) =>
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _project,
              builder: (context, project) =>
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _deliveries,
                    builder: (context, deliveries) {
                      if (actor.hasError ||
                          project.hasError ||
                          deliveries.hasError)
                        return const Text(
                          'No pudimos consultar el cierre del proyecto. Revisa conexión y permisos.',
                        );
                      if (!actor.hasData ||
                          !project.hasData ||
                          !deliveries.hasData)
                        return const LinearProgressIndicator();
                      if (!project.data!.exists)
                        return const Text('El proyecto ya no está disponible.');
                      final data = project.data!.data()!;
                      final active =
                          actor.data!.exists &&
                          actor.data!.data()?['activo'] != false;
                      final admin =
                          active && actor.data!.data()?['rol'] == 'admin';
                      final assigned =
                          active &&
                          data['encargados'] is List &&
                          (data['encargados'] as List).contains(
                            FirebaseAuth.instance.currentUser?.uid,
                          );
                      final closed = [
                        'finalizado',
                        'completado',
                      ].contains(data['estatus']);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProjectClosureActions(
                            admin: admin,
                            assigned: assigned,
                            closed: closed,
                            delivered: deliveries.data!.docs.isNotEmpty,
                            enabled:
                                !_busy &&
                                !project.data!.metadata.isFromCache &&
                                !actor.data!.metadata.isFromCache,
                            onComplete: () => _save(false),
                            onApprove: () => _save(true),
                          ),
                          if (_busy) const LinearProgressIndicator(),
                          if (_error != null)
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
            ),
      ),
    ),
  );
}
