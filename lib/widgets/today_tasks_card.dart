import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';
import '../screens/daily_tasks_screen.dart';
import '../screens/admin_team_progress_screen.dart';
import '../screens/work_workspace_screen.dart';
import '../presentation/appearance.dart';
import '../workflow/task_lifecycle.dart';
import 'quick_task_actions.dart';
import '../services/offline_workspace.dart';

class TodayTasksCard extends StatefulWidget {
  final UserModel user;
  final CompanyLearningService? service;
  final TaskPhotoCapture? capturePhoto;
  const TodayTasksCard({
    super.key,
    required this.user,
    this.service,
    this.capturePhoto,
  });
  @override
  State<TodayTasksCard> createState() => _TodayTasksState();
}

class _TodayTasksState extends State<TodayTasksCard>
    with WidgetsBindingObserver {
  late CompanyLearningService _api;
  int _generation = 0;
  bool _busy = false, _cached = false, _pendingSync = false;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];
  @override
  void initState() {
    super.initState();
    _api = widget.service ?? CompanyLearningService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant TodayTasksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.rol != widget.user.rol ||
        oldWidget.service != widget.service) {
      _generation++;
      _tasks = [];
      _busy = false;
      _error = null;
      _api = widget.service ?? CompanyLearningService();
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.call('daily-list', {
        'day': AttendanceGatewayService.dayKey(AttendanceGatewayService.today),
        'includePending': true,
      });
      if (mounted && generation == _generation) {
        setState(() {
          _tasks = (result['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          _cached = result['cached'] == true;
          _pendingSync = result['pendingSync'] == true;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() {
          _tasks = [];
          _error = CompanyLearningService.message(error);
        });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> task) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            taskDestination(user: widget.user, task: task, service: _api),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final mine = _tasks
        .where((t) => taskAssignedTo(t, widget.user.id))
        .toList();
    final pending = mine
        .where(
          (t) =>
              t['status'] != 'completado' &&
              !(widget.user.rol == 'admin' && t['status'] == 'en_revision'),
        )
        .toList();
    final reviews = widget.user.rol == 'admin'
        ? _tasks.where((t) => t['status'] == 'en_revision').toList()
        : <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis actividades de hoy',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar tus tareas',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Text(
          '${mine.where((t) => t['status'] == 'completado').length} de ${mine.length} aprobadas · incluye pendientes anteriores',
          style: TextStyle(color: StiloColors.text.withValues(alpha: .65)),
        ),
        OfflineDataBadge(cached: _cached, pending: _pendingSync),
        if (_busy && _tasks.isEmpty) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!),
          ),
        if (!_busy && _error == null && pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No tienes pendientes del día. Aquí aparecerán tus asignaciones y tareas extras.',
              ),
            ),
          ),
        for (final task in pending.take(3))
          WorkTaskCard(
            key: ValueKey('home-${task['taskId']}'),
            task: task,
            user: widget.user,
            service: _api,
            onChanged: _load,
            capturePhoto: widget.capturePhoto,
            quickActions: true,
            onTap: () => _open(task),
          ),
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${reviews.length} entregas por aprobar',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          for (final task in reviews.take(3))
            WorkTaskCard(
              key: ValueKey('review-${task['taskId']}'),
              task: task,
              user: widget.user,
              service: _api,
              onChanged: _load,
              quickActions: true,
              onTap: () => _open(task),
            ),
        ],
        if (widget.user.rol == AppRoles.admin)
          FilledButton.tonalIcon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AdminTeamProgressScreen(
                    user: widget.user,
                    service: widget.service,
                  ),
                ),
              );
              if (mounted) await _load();
            },
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Ver avances de todo el equipo'),
          ),
        TextButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => EquipoTareasScreen(usuario: widget.user),
              ),
            );
            if (mounted) await _load();
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Ver todas las tareas y actividades'),
        ),
      ],
    );
  }
}
