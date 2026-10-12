import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../presentation/appearance.dart';
import '../services/company_learning_service.dart';
import '../widgets/soft_workspace.dart';
import '../workflow/team_progress.dart';
import '../widgets/work_status.dart';
import 'daily_tasks_screen.dart';

class AdminTeamProgressScreen extends StatefulWidget {
  final UserModel user;
  final CompanyLearningService? service;
  final bool embedded;
  const AdminTeamProgressScreen({
    super.key,
    required this.user,
    this.service,
    this.embedded = false,
  });
  @override
  State<AdminTeamProgressScreen> createState() => _TeamProgressState();
}

class _TeamProgressState extends State<AdminTeamProgressScreen>
    with WidgetsBindingObserver {
  final _defaultService = CompanyLearningService();
  CompanyLearningService get _api => widget.service ?? _defaultService;
  List<Map<String, dynamic>> _items = [], _people = [], _projects = [];
  String _person = 'all',
      _department = 'all',
      _project = 'all',
      _period = 'all',
      _kind = 'all',
      _status = 'todas',
      _search = '';
  String? _error;
  bool _busy = false, _loaded = false, _sessionChanged = false, _cached = false;
  int _generation = 0;
  DateTime? _updatedAt;
  StreamSubscription<User?>? _auth;
  bool get _admin => widget.user.rol == AppRoles.admin;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    if (!_admin) return;
    if (widget.service == null) {
      try {
        _auth = FirebaseAuth.instance.authStateChanges().listen((session) {
          if (mounted && session?.uid != widget.user.id) {
            ++_generation;
            setState(() {
              _sessionChanged = true;
              _clear();
              _error =
                  'Tu sesión cambió. Abre este panel con tu cuenta de Administración.';
            });
          }
        });
      } catch (_) {
        _sessionChanged = true;
        _error = 'No se pudo verificar tu sesión. Inicia sesión de nuevo.';
        return;
      }
    }
    unawaited(_load());
  }

  void _clear() {
    _items = [];
    _people = [];
    _projects = [];
    _loaded = false;
    _busy = false;
    _updatedAt = null;
    _cached = false;
  }

  @override
  void didUpdateWidget(covariant AdminTeamProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.rol != widget.user.rol ||
        oldWidget.service != widget.service) {
      ++_generation;
      _auth?.cancel();
      _clear();
      _sessionChanged = false;
      _error = null;
      _person = _department = _project = _period = _kind = 'all';
      _status = 'todas';
      _search = '';
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    ++_generation;
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_admin || _busy || _sessionChanged) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.call('daily-admin-overview', {
        'viewerId': widget.user.id,
      });
      if (!mounted || generation != _generation || !_admin) return;
      if (response['viewerId'] != widget.user.id)
        throw StateError(
          'La sesión cambió. Vuelve a abrir el panel con tu cuenta.',
        );
      List<Map<String, dynamic>> rows(String key) => (response[key] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final tasks = rows('items');
      setState(() {
        _items = {
          for (final task in tasks) task['taskId']: task,
        }.values.toList();
        final people = {
          for (final person in rows('people')) person['id']: person,
        };
        for (final task in _items) {
          final id = task['userId'];
          if (id != null && id != '' && !people.containsKey(id)) {
            people[id] = {
              'id': id,
              'name': task['userName'] ?? 'Integrante',
              'role': 'Perfil no disponible',
              'department': '',
            };
          }
        }
        _people = people.values.toList()
          ..sort(
            (a, b) => a['name'].toString().compareTo(b['name'].toString()),
          );
        _cached = response['cached'] == true;
        _projects = rows('projects');
        _loaded = true;
        _updatedAt = DateTime.now();
        if (!_people.any((p) => p['id'] == _person)) _person = 'all';
        if (!_people.any((p) => p['department'] == _department))
          _department = 'all';
        if (!_projects.any((p) => p['id'] == _project)) _project = 'all';
      });
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() {
          _clear();
          _error = CompanyLearningService.message(error);
        });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _filtered({bool state = true}) {
    final people = {for (final p in _people) p['id']: p};
    return _items.where((t) {
      if (_person != 'all' && t['userId'] != _person ||
          _department != 'all' &&
              people[t['userId']]?['department'] != _department ||
          _project != 'all' && t['projectId'] != _project ||
          _kind != 'all' && t['workKind'] != _kind)
        return false;
      if (!teamTaskInPeriod(t, _period)) return false;
      final searchable =
          '${t['title']} ${t['userName']} ${t['details']} ${_projectName(t)}'
              .toLowerCase();
      if (_search.isNotEmpty && !searchable.contains(_search)) return false;
      return !state ||
          switch (_status) {
            'pendiente' => t['status'] == 'pendiente',
            'en_progreso' => t['status'] == 'en_progreso',
            'en_revision' => t['status'] == 'en_revision',
            'completado' => t['status'] == 'completado',
            'cambios_solicitados' => t['status'] == 'cambios_solicitados',
            'vencidas' => teamTaskOverdue(t),
            _ => true,
          };
    }).toList()..sort((a, b) {
      int priority(Map<String, dynamic> t) => t['status'] == 'en_revision'
          ? 0
          : teamTaskOverdue(t)
          ? 1
          : t['status'] == 'completado'
          ? 3
          : 2;
      final order = priority(a).compareTo(priority(b));
      return order != 0
          ? order
          : (a['dueAt'] ?? a['dueDay'] ?? '').toString().compareTo(
              (b['dueAt'] ?? b['dueDay'] ?? '').toString(),
            );
    });
  }

  String get _additionalFilters {
    final labels = [
      if (_department != 'all') _department,
      if (_project != 'all') _projectName({'projectId': _project}),
      if (_period != 'all')
        {'today': 'Hoy', 'week': 'Esta semana', 'month': 'Este mes'}[_period]!,
      if (_kind != 'all') workKindLabel(_kind),
    ];
    return labels.isEmpty
        ? 'Departamento, proyecto, fechas y tipo'
        : labels.join(' · ');
  }

  String _projectName(Map<String, dynamic> task) {
    final id = task['projectId'];
    return _projects
            .where((p) => p['id'] == id)
            .map((p) => p['title'].toString())
            .firstOrNull ??
        (id == null || id == '' ? 'Sin proyecto' : 'Proyecto');
  }

  Widget _select(
    String key,
    String label,
    String selected,
    Map<String, String> choices,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey(key),
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: choices.entries
        .map(
          (v) => DropdownMenuItem(
            value: v.key,
            child: Text(v.value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) setState(() => changed(value));
    },
  );
  Future<void> _open(Map<String, dynamic> task) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DailyTaskDetail(user: widget.user, task: task, service: _api),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_admin)
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo Administración puede ver los avances de todo el equipo.',
            ),
          ),
        ),
      );
    final rows = _filtered(),
        scope = _filtered(state: false),
        stats = TeamProgressStats.from(scope);
    final departments =
        _people
            .map((p) => (p['department'] ?? '').toString())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Avances del equipo'),
              actions: [
                IconButton(
                  tooltip: 'Actualizar avances del equipo',
                  onPressed: _busy || _sessionChanged ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            const StiloSectionHero(
              eyebrow: 'STILO · ADMINISTRACIÓN',
              title: 'Todo el equipo, a la vista.',
              subtitle:
                  'Tareas, porcentajes y evidencias. Revisa cada entrega y confirma qué trabajo ya fue aprobado.',
              icon: Icons.insights_rounded,
              compact: true,
            ),
            const SizedBox(height: 18),
            if (widget.embedded)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy || _sessionChanged ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _busy || _sessionChanged ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loaded) ...[
              if (_cached)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Información guardada en este dispositivo. Conecta a Internet para actualizar los avances.',
                  ),
                ),
              const Text(
                'Resumen de la selección · todos los estados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Última actualización: ${_updatedAt!.hour.toString().padLeft(2, '0')}:${_updatedAt!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: StiloColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${stats.total} tareas')),
                  Chip(label: Text('${stats.review} por aprobar')),
                  Chip(label: Text('${stats.approved} aprobadas')),
                  Chip(label: Text('${stats.overdue} vencidas')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                scope.isEmpty
                    ? 'Sin asignaciones en esta selección.'
                    : 'Avance promedio: ${stats.percentage} % · ${stats.approved} de ${stats.total} aprobadas',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('team-search'),
                decoration: const InputDecoration(
                  labelText: 'Buscar tarea, persona o proyecto',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) =>
                    setState(() => _search = value.toLowerCase().trim()),
              ),
              const SizedBox(height: 14),
              _select('team-person', 'Persona', _person, {
                'all': 'Todo el equipo',
                for (final p in _people)
                  p['id'].toString(): p['name'].toString(),
              }, (v) => _person = v),
              const SizedBox(height: 12),
              ExpansionTile(
                key: const ValueKey('team-filters'),
                maintainState: true,
                title: const Text('Más filtros'),
                subtitle: Text(_additionalFilters),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 700 &&
                                MediaQuery.textScalerOf(context).scale(1) < 1.5
                            ? 3
                            : constraints.maxWidth >= 480 &&
                                  MediaQuery.textScalerOf(context).scale(1) <
                                      1.5
                            ? 2
                            : 1;
                        final width =
                            (constraints.maxWidth - 12 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: width,
                              child: _select(
                                'team-department',
                                'Departamento',
                                _department,
                                {
                                  'all': 'Todos los departamentos',
                                  for (final area in departments) area: area,
                                },
                                (v) => _department = v,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _select(
                                'team-project',
                                'Proyecto',
                                _project,
                                {
                                  'all': 'Todos los proyectos',
                                  for (final p in _projects)
                                    p['id'].toString(): p['title'].toString(),
                                },
                                (v) => _project = v,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _select(
                                'team-period',
                                'Periodo',
                                _period,
                                const {
                                  'all': 'Todas las fechas',
                                  'today': 'Hoy',
                                  'week': 'Esta semana',
                                  'month': 'Este mes',
                                },
                                (v) => _period = v,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _select(
                                'team-kind',
                                'Tipo de trabajo',
                                _kind,
                                const {
                                  'all': 'Todos los tipos',
                                  'dia': 'Del día',
                                  'extra': 'Extras',
                                  'proyecto': 'Actividades de proyectos',
                                  'instalacion': 'Instalaciones',
                                  'envio': 'Envíos',
                                },
                                (v) => _kind = v,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_department != 'all' ||
                      _project != 'all' ||
                      _period != 'all' ||
                      _kind != 'all')
                    TextButton(
                      onPressed: () => setState(
                        () => _department = _project = _period = _kind = 'all',
                      ),
                      child: const Text('Limpiar filtros adicionales'),
                    ),
                ],
              ),
              if (_period != 'all')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Por fecha de asignación; incluye pendientes anteriores. Las aprobaciones anteriores se consultan en Todas las fechas.',
                  ),
                ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const {
                      'todas': 'Todas',
                      'en_revision': 'Por aprobar',
                      'completado': 'Aprobadas',
                      'vencidas': 'Vencidas',
                      'pendiente': 'Pendientes',
                      'en_progreso': 'En progreso',
                      'cambios_solicitados': 'Requieren cambios',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _status == entry.key,
                          onSelected: (_) =>
                              setState(() => _status = entry.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                key: const ValueKey('team-people'),
                title: const Text('Por persona'),
                subtitle: const Text(
                  'Avance y tareas aprobadas de cada integrante',
                ),
                children: [
                  for (final person in _people.where(
                    (p) =>
                        (_person == 'all' || p['id'] == _person) &&
                        (_department == 'all' ||
                            p['department'] == _department),
                  ))
                    _personCard(
                      person,
                      scope.where((t) => t['userId'] == person['id']).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${rows.length} tareas en esta vista',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No hay tareas con estos filtros. Prueba otra selección.',
                  ),
                ),
              for (final task in rows)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((task['projectId'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 10),
                        child: Text(
                          _projectName(task),
                          style: TextStyle(
                            fontSize: 12,
                            color: StiloColors.muted,
                          ),
                        ),
                      ),
                    if (teamTaskOverdue(task))
                      const Padding(
                        padding: EdgeInsets.only(left: 10, top: 6),
                        child: Text(
                          'Entrega vencida',
                          style: TextStyle(
                            color: Color(0xFFFF7E91),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    WorkTaskCard(
                      task: task,
                      user: widget.user,
                      onTap: () => _open(task),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _personCard(
    Map<String, dynamic> person,
    List<Map<String, dynamic>> tasks,
  ) {
    final stats = TeamProgressStats.from(tasks);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person['name'].toString(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '${person['department'] ?? ''} · ${person['role']}${person['active'] == false ? ' · Cuenta inactiva' : ''}',
              style: TextStyle(color: StiloColors.muted),
            ),
            const SizedBox(height: 10),
            Text(
              stats.total == 0
                  ? 'Sin asignaciones en esta selección.'
                  : '${stats.approved} de ${stats.total} aprobadas · ${stats.review} por aprobar · ${stats.overdue} vencidas',
            ),
            if (stats.total > 0) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: stats.percentage / 100,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              Text('${stats.percentage} % de avance promedio'),
            ],
            TextButton.icon(
              onPressed: () =>
                  setState(() => _person = person['id'].toString()),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Ver sus tareas'),
            ),
          ],
        ),
      ),
    );
  }
}
