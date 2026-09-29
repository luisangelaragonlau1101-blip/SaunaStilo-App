import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';
import '../screens/daily_tasks_screen.dart';
import '../screens/work_workspace_screen.dart';
import '../presentation/appearance.dart';

class TodayTasksCard extends StatefulWidget {
  final UserModel user;
  final CompanyLearningService? service;
  const TodayTasksCard({super.key, required this.user, this.service});
  @override State<TodayTasksCard> createState() => _TodayTasksState();
}
class _TodayTasksState extends State<TodayTasksCard> with WidgetsBindingObserver {
  late final _api = widget.service ?? CompanyLearningService();
  Timer? _timer;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && TickerMode.of(context) && WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused && WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden) unawaited(_load());
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) unawaited(_load()); }
  @override void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _api.call('daily-list', {'day': AttendanceGatewayService.dayKey(AttendanceGatewayService.today)});
      if (mounted) setState(() => _tasks = (result['items'] as List).map((v) => Map<String, dynamic>.from(v as Map)).where((t) => t['userId'] == widget.user.id).toList());
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) {
    final pending = _tasks.where((t) => t['status'] != 'completado').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [const Expanded(child: Text('Tus tareas del día', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        IconButton(tooltip: 'Actualizar tus tareas', onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      Text('${_tasks.length - pending.length} de ${_tasks.length} aprobadas hoy', style: TextStyle(color: StiloColors.text.withValues(alpha: .65))),
      if (_busy && _tasks.isEmpty) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!)),
      if (!_busy && _error == null && pending.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No tienes pendientes del día. Aquí aparecerán tus asignaciones y tareas extras.'))),
      for (final task in pending.take(3)) WorkTaskCard(task: task, onTap: () async {
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DailyTaskDetail(user: widget.user, task: task, service: _api)));
        if (mounted) await _load();
      }),
      TextButton.icon(onPressed: () async {
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EquipoTareasScreen(usuario: widget.user)));
        if (mounted) await _load();
      }, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Ver todas las tareas y actividades')),
    ]);
  }
}
