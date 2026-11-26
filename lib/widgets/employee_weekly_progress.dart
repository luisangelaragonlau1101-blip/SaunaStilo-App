import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/employee_productivity_service.dart';
import '../workflow/productivity_2026.dart';

/// Loads independently after the first frame. Failure never blocks today's work.
class EmployeeWeeklyProgress extends StatefulWidget {
  final UserModel user;
  final EmployeeProductivityService? service;
  final bool detailed;
  const EmployeeWeeklyProgress({
    super.key,
    required this.user,
    this.service,
    this.detailed = false,
  });
  @override
  State<EmployeeWeeklyProgress> createState() => _EmployeeWeeklyProgressState();
}

class _EmployeeWeeklyProgressState extends State<EmployeeWeeklyProgress>
    with WidgetsBindingObserver {
  final _defaultService = EmployeeProductivityService();
  ProductivitySnapshot? _snapshot;
  String? _error;
  bool _busy = false, _sessionChanged = false;
  int _generation = 0;
  StreamSubscription<User?>? _auth;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    if (widget.service == null) {
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted && user?.uid != widget.user.id) {
          ++_generation;
          setState(() {
            _snapshot = null;
            _busy = false;
            _sessionChanged = true;
            _error = 'Tu sesión cambió. Abre tus avances desde tu cuenta.';
          });
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_sessionChanged) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant EmployeeWeeklyProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.service != widget.service) {
      ++_generation;
      _auth?.cancel();
      _snapshot = null;
      _busy = false;
      _sessionChanged = false;
      _error = null;
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    if (_busy || _sessionChanged) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (widget.service ?? _defaultService).load(
        widget.user.id,
      );
      if (mounted && generation == _generation)
        setState(() => _snapshot = result);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _snapshot = null;
          _error =
              'No pudimos actualizar tus avances. Reintenta cuando tengas conexión.';
        });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Mi avance semanal',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar mis avances',
                onPressed: _busy || _sessionChanged ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_snapshot != null) ...[
            if (_snapshot!.cached)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Copia local. Conecta para actualizar las aprobaciones.',
                ),
              ),
            ProductivitySummaryView(
              report: _snapshot!.report,
              detailed: widget.detailed,
            ),
            if (!widget.detailed)
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EmployeeProductivityScreen(
                      user: widget.user,
                      service: widget.service,
                    ),
                  ),
                ),
                icon: const Icon(Icons.bar_chart_rounded),
                label: const Text('Ver mis avances'),
              ),
          ] else if (_error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aquí verás tus actividades aprobadas y tu progreso.',
              ),
            ),
        ],
      ),
    ),
  );
}

class EmployeeProductivityScreen extends StatelessWidget {
  final UserModel user;
  final EmployeeProductivityService? service;
  const EmployeeProductivityScreen({
    super.key,
    required this.user,
    this.service,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis avances')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EmployeeWeeklyProgress(user: user, service: service, detailed: true),
      ],
    ),
  );
}

class ProductivitySummaryView extends StatelessWidget {
  final WorkProductivity report;
  final bool detailed;
  const ProductivitySummaryView({
    super.key,
    required this.report,
    this.detailed = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(
            avatar: const Icon(Icons.task_alt_rounded, size: 18),
            label: Text('${report.approvedWeek} aprobadas esta semana'),
          ),
          Chip(label: Text('${report.pending} pendientes')),
          Chip(label: Text('${report.review} en revisión')),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        '${report.currentStreak} jornadas de racha',
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
      const Text(
        'Jornadas con alguna actividad asignada y aprobada. Descansos, permisos aprobados y días sin asignaciones no interrumpen tu racha.',
      ),
      const SizedBox(height: 16),
      ProductivityChart(buckets: report.weekly),
      if (report.approvedWeek > 0)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: Color(0xFFE9BE6C),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.approvedWeek >= 5
                      ? 'Constancia que se nota: ${report.approvedWeek} actividades aprobadas.'
                      : 'Tu trabajo cuenta: ya tienes actividades aprobadas esta semana.',
                ),
              ),
            ],
          ),
        ),
      if (detailed) ...[
        const SizedBox(height: 22),
        Text(
          '${report.approvedMonth} aprobadas este mes',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        ProductivityChart(buckets: report.monthly, monthly: true),
        const SizedBox(height: 14),
        Text('Mejor racha del periodo: ${report.bestStreak} jornadas.'),
        const Text(
          'Las gráficas usan la fecha real de aprobación. Las entregas por revisar todavía no cuentan como aprobadas. Cada actividad compartida se cuenta una vez en tu resumen.',
        ),
        if (report.unknownApprovalDate > 0)
          Text(
            '${report.unknownApprovalDate} aprobaciones históricas sin fecha no se asignan a una semana inventada.',
          ),
      ],
      const SizedBox(height: 12),
      Text(
        'Racha observada desde ${report.observedSince.day}/${report.observedSince.month}/${report.observedSince.year}.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (report.partial)
        const Text(
          'Resumen parcial por volumen de actividades. No representa todos los registros; consulta tus tareas para ampliar la revisión.',
        ),
    ],
  );
}

/// Semantic labels retain exact counts even when the visible bar is tiny.
class ProductivityChart extends StatelessWidget {
  final List<ProductivityBucket> buckets;
  final bool monthly;
  const ProductivityChart({
    super.key,
    required this.buckets,
    this.monthly = false,
  });
  @override
  Widget build(BuildContext context) {
    final maximum = buckets.fold<int>(1, (m, b) => math.max(m, b.approved));
    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bucket in buckets)
          Expanded(
            child: Semantics(
              label:
                  '${bucket.day.day}/${bucket.day.month}: ${bucket.approved} actividades aprobadas',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${bucket.approved}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 62,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 24,
                          height: bucket.approved == 0
                              ? 3
                              : 8 + 54 * bucket.approved / maximum,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary
                                .withValues(
                                  alpha: bucket.approved == 0 ? .15 : .8,
                                ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      monthly
                          ? '${bucket.day.day}'
                          : weekdays[bucket.day.weekday - 1],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
