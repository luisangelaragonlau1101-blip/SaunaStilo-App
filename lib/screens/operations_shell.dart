import '../widgets/workday_home.dart';
import '../widgets/enterprise_pending_summary.dart';
import '../widgets/installation_home_card.dart';
import '../widgets/employee_weekly_progress.dart';
import '../services/startup_metrics.dart';
import '../presentation/modern_workspace.dart';
import '../widgets/today_tasks_card.dart';
import '../presentation/appearance.dart';
import '../widgets/personal_header.dart';
import 'business_workspace_screen.dart';
import '../widgets/home_shortcuts.dart';
import 'daily_tasks_screen.dart';
import 'configuracion_screen.dart';
import 'admin_inbox_screen.dart';
import 'engineering_screen.dart';
import '../services/external_transfer.dart';
import '../widgets/home_progress_panel.dart';
import 'training_access_screen.dart';
import 'personal_day_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/actividad_model.dart';
import '../models/user_model.dart';
import '../services/app_action_catalog.dart';
import '../widgets/jornada_compacta.dart';
import '../widgets/stilo_orbit.dart';
import '../widgets/personal_message_overlay.dart';
import 'admin_modal_detalle_actividad.dart' as admin_detail;
import 'trabajador_modal_detalle_actividad.dart' as worker_detail;
import 'blog_interno_screen.dart';
import 'mensajes_equipo_screen.dart';
import 'perfil_social_screen.dart';
import 'online_smart_screen.dart';
import 'project_workspace_screen.dart';
import 'equipo_tareas_screen.dart';

final operationsDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: 'Inicio',
  ),
  NavigationDestination(
    icon: Icon(Icons.apps_outlined),
    selectedIcon: Icon(Icons.apps_rounded),
    label: 'Más',
  ),
  NavigationDestination(
    icon: Icon(Icons.forum_outlined),
    selectedIcon: Icon(Icons.forum_rounded),
    label: 'Mensajes',
  ),
  NavigationDestination(
    icon: Icon(Icons.assignment_outlined),
    selectedIcon: Icon(Icons.assignment_rounded),
    label: 'Tareas',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
    label: 'Perfil',
  ),
];

class OperationsShell extends StatefulWidget {
  final UserModel usuario;
  const OperationsShell({super.key, required this.usuario});
  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) StartupMetrics.mark('home-first-frame');
    });
  }

  final _bodyKey = GlobalKey();
  final Map<int, Widget> _pages = {};
  @override
  void didUpdateWidget(covariant OperationsShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario != widget.usuario) _pages.clear();
    if (oldWidget.usuario.id != widget.usuario.id ||
        oldWidget.usuario.rol != widget.usuario.rol)
      _index = 0;
  }

  void _personalMenu() {
    final actions = AppActionCatalog.mainMenu(widget.usuario);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: StiloColors.surface,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .82,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Text(
              'Todas mis opciones',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            for (final a in actions)
              ListTile(
                leading: Icon(a.icon, color: a.color),
                title: Text(a.title),
                subtitle: Text(a.subtitle),
                onTap: () {
                  Navigator.pop(c);
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: a.builder));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _page(int index) => _pages.putIfAbsent(
    index,
    () => switch (index) {
      1 => _WorkspaceOptions(user: widget.usuario),
      2 => MensajesEquipoScreen(usuario: widget.usuario),
      3 => EquipoTareasScreen(usuario: widget.usuario),
      4 => ConfiguracionScreen(usuario: widget.usuario, embedded: true),
      _ => _OperationsHome(
        usuario: widget.usuario,
        onTab: (i) => setState(() => _index = i),
      ),
    },
  );
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    _page(_index);
    final body = IndexedStack(
      key: _bodyKey,
      index: _index,
      children: List<Widget>.generate(
        5,
        (i) => TickerMode(
          enabled: i == _index,
          child: _pages[i] ?? SizedBox.shrink(),
        ),
      ),
    );
    return PersonalMessageOverlay(
      usuario: widget.usuario,
      child: AppearanceController.instance.modern
          ? ModernWorkspaceFrame(
              selectedIndex: _index,
              destinations: operationsDestinations,
              onSelected: (i) => setState(() => _index = i),
              child: body,
            )
          : Scaffold(
              backgroundColor: StiloColors.background,
              body: body,
              bottomNavigationBar: StiloDock(
                selectedIndex: _index,
                destinations: operationsDestinations,
                onSelected: (i) => setState(() => _index = i),
              ),
            ),
    );
  }
}

class _OperationsHome extends StatefulWidget {
  final UserModel usuario;
  final ValueChanged<int> onTab;
  _OperationsHome({required this.usuario, required this.onTab});
  @override
  State<_OperationsHome> createState() => _OperationsHomeState();
}

class _OperationsHomeState extends State<_OperationsHome> {
  String _search = '';
  bool _all = false;
  @override
  void initState() {
    super.initState();
    AppearanceController.instance.addListener(_appearanceChanged);
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppearanceController.instance.removeListener(_appearanceChanged);
    super.dispose();
  }

  void _open(AppAction action) {
    if (action.id == 'proyectos') {
      widget.onTab(3);
      return;
    }
    if (action.id == 'mensajes') {
      widget.onTab(2);
      return;
    }
    if (action.id == 'tareas') {
      widget.onTab(3);
      return;
    }
    if (action.id == 'perfil' || action.id == 'configuracion') {
      widget.onTab(4);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: action.id == 'ia' || action.id == 'guia'
            ? (_) => OnlineSmartScreen(
                usuario: widget.usuario,
                modoGuia: action.id == 'guia',
              )
            : action.builder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final actions = AppActionCatalog.mainMenu(widget.usuario);

    return WorkdayHome(
      administrator: widget.usuario.rol == AppRoles.admin,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/logo_saunastilo.png',
                width: 120,
                height: 44,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              for (final id in ['avisos', 'perfil'])
                IconButton(
                  tooltip: actions.firstWhere((a) => a.id == id).title,
                  onPressed: () => _open(actions.firstWhere((a) => a.id == id)),
                  icon: Icon(
                    id == 'avisos'
                        ? Icons.notifications_none_rounded
                        : Icons.account_circle_outlined,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hola, ${widget.usuario.nombre.trim().split(' ').first}',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const Text('Lo que necesitas hacer hoy, aquí mismo.'),
        ],
      ),
      enterprise: EnterprisePendingSummary(user: widget.usuario),
      journey: JornadaCompacta(usuario: widget.usuario),
      activities: TodayTasksCard(user: widget.usuario),
      installations: InstallationHomeCard(user: widget.usuario),
      weekly: EmployeeWeeklyProgress(user: widget.usuario),
      options: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MainHomeShortcuts(user: widget.usuario, onTab: widget.onTab),
          const SizedBox(height: 12),
          TextField(
            contextMenuBuilder: privacyTextMenu,
            decoration: const InputDecoration(
              hintText: 'Buscar una opción…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _all = !_all),
            icon: Icon(_all ? Icons.expand_less_rounded : Icons.apps_rounded),
            label: Text(_all ? 'Cerrar menú completo' : 'Todas mis opciones'),
          ),
          if (_all || _search.trim().isNotEmpty)
            ...actions
                .where((a) => a.matches(_search))
                .map(
                  (a) => Card(
                    child: ListTile(
                      leading: Icon(a.icon, color: a.color),
                      title: Text(a.title),
                      subtitle: Text(a.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(a),
                    ),
                  ),
                ),
        ],
      ),
      secondary: _OptionalAchievements(
        user: widget.usuario,
        onProfile: () => widget.onTab(4),
      ),
    );
  }
}

class OperationsTaskList extends StatelessWidget {
  final UserModel usuario;
  final bool compact;
  const OperationsTaskList({
    super.key,
    required this.usuario,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final admin = usuario.rol == AppRoles.admin;
    final query = admin
        ? FirebaseFirestore.instance.collection('actividades')
        : FirebaseFirestore.instance
              .collection('actividades')
              .where('asignadoATrabajadorId', isEqualTo: usuario.id);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No pudimos consultar las tareas. Revisa conexión y permisos.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          );
        if (!snapshot.hasData)
          return Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        final tasks =
            snapshot.data!.docs
                .map((d) => ActividadModel.fromJson(d.data(), d.id))
                .where((a) => !compact || !a.aprobada)
                .toList()
              ..sort((a, b) => a.fechaTermino.compareTo(b.fechaTermino));
        if (tasks.isEmpty)
          return Container(
            padding: EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: StiloColors.surface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'No hay tareas pendientes en esta vista.',
              style: TextStyle(color: StiloColors.text.withValues(alpha: .60)),
            ),
          );
        return Column(
          children: (compact ? tasks.take(4) : tasks)
              .map(
                (task) => Card(
                  color: StiloColors.surface,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    leading: Icon(
                      task.estatus == 'completado'
                          ? Icons.task_alt_rounded
                          : Icons.assignment_outlined,
                      color: StiloColors.accent,
                    ),
                    title: Text(
                      task.titulo,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd/MM HH:mm').format(task.fechaTermino)} · ${task.estatus.replaceAll('_', ' ')}',
                    ),
                    trailing: Icon(Icons.chevron_right_rounded),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => admin
                          ? admin_detail.ModalDetalleActividad(actividad: task)
                          : worker_detail.ModalDetalleActividad(
                              actividad: task,
                            ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OptionalAchievements extends StatefulWidget {
  final UserModel user;
  final VoidCallback onProfile;
  const _OptionalAchievements({required this.user, required this.onProfile});
  @override
  State<_OptionalAchievements> createState() => _OptionalAchievementsState();
}

class _OptionalAchievementsState extends State<_OptionalAchievements> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Mis logros y aprendizaje'),
    onExpansionChanged: (value) => setState(() => _expanded = value),
    children: [
      if (_expanded)
        HomeProgressPanel(
          user: widget.user,
          onStreak: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: AppActionCatalog.forUser(widget.user)
                  .firstWhere(
                    (a) =>
                        a.id ==
                        (widget.user.rol == AppRoles.admin
                            ? 'rachas'
                            : 'racha'),
                  )
                  .builder,
            ),
          ),
          onProfile: widget.onProfile,
          onLearn: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TrainingAccessScreen(user: widget.user),
            ),
          ),
        ),
    ],
  );
}

class _WorkspaceOptions extends StatefulWidget {
  final UserModel user;
  const _WorkspaceOptions({required this.user});
  @override
  State<_WorkspaceOptions> createState() => _WorkspaceOptionsState();
}

class _WorkspaceOptionsState extends State<_WorkspaceOptions> {
  String _search = '';
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Todas mis opciones',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 12),
        for (final action in AppActionCatalog.mainMenu(
          widget.user,
        ).where((a) => a.matches(_search)))
          Card(
            child: ListTile(
              leading: Icon(action.icon, color: action.color),
              title: Text(action.title),
              subtitle: Text(action.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: action.builder),
              ),
            ),
          ),
      ],
    ),
  );
}
