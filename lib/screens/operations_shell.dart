import '../services/external_transfer.dart';
import '../widgets/home_progress_panel.dart';
import 'training_access_screen.dart';
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

const operationsDestinations = <NavigationDestination>[
  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
  NavigationDestination(icon: Icon(Icons.auto_awesome_mosaic_outlined), selectedIcon: Icon(Icons.auto_awesome_mosaic_rounded), label: 'Comunidad'),
  NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Chats'),
  NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tareas'),
  NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
];

class OperationsShell extends StatefulWidget {
  final UserModel usuario;
  const OperationsShell({super.key, required this.usuario});
  @override
  State<OperationsShell> createState() => _OperationsShellState();
}
class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;
  final Map<int, Widget> _pages = {};
  @override
  void didUpdateWidget(covariant OperationsShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario != widget.usuario) _pages.clear();
    if (oldWidget.usuario.id != widget.usuario.id || oldWidget.usuario.rol != widget.usuario.rol) _index = 0;
  }
  Widget _page(int index) => _pages.putIfAbsent(index, () => switch (index) {
    1 => BlogInternoScreen(usuario: widget.usuario),
    2 => MensajesEquipoScreen(usuario: widget.usuario),
    3 => EquipoTareasScreen(usuario: widget.usuario),
    4 => PerfilSocialScreen(usuarioActual: widget.usuario, perfilId: widget.usuario.id),
    _ => _OperationsHome(usuario: widget.usuario, onTab: (i) => setState(() => _index = i)),
  });
  @override
  Widget build(BuildContext context) {
    _page(_index);
    return PersonalMessageOverlay(usuario: widget.usuario, child: Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _index, children: List<Widget>.generate(5, (i) => TickerMode(enabled: i == _index, child: _pages[i] ?? const SizedBox.shrink()))),
      bottomNavigationBar: StiloDock(selectedIndex: _index, destinations: operationsDestinations, onSelected: (i) => setState(() => _index = i)),
    ));
  }
}

class _OperationsHome extends StatefulWidget {
  final UserModel usuario;
  final ValueChanged<int> onTab;
  const _OperationsHome({required this.usuario, required this.onTab});
  @override
  State<_OperationsHome> createState() => _OperationsHomeState();
}
class _OperationsHomeState extends State<_OperationsHome> {
  String _search = '';
  bool _all = false;
  void _open(AppAction action) {
    if (action.id == 'proyectos') { Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectWorkspaceScreen(usuario: widget.usuario))); return; }
    if (action.id == 'comunidad') { widget.onTab(1); return; }
    if (action.id == 'mensajes') { widget.onTab(2); return; }
    if (action.id == 'tareas') { widget.onTab(3); return; }
    if (action.id == 'perfil') { widget.onTab(4); return; }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: action.id == 'ia' || action.id == 'guia' ? (_) => OnlineSmartScreen(usuario: widget.usuario, modoGuia: action.id == 'guia') : action.builder));
  }
  @override
  Widget build(BuildContext context) {
    final actions = AppActionCatalog.forUser(widget.usuario);
    final quick = actions.where((a) => ['proyectos', 'asistencia', 'inventario', 'racha', 'rachas', 'asistencias', 'prestamos', 'justificar', 'cumpleanos', 'equipo', 'almacen_movimientos', 'solicitudes_almacen', 'sin_conexion', 'juegos'].contains(a.id)).toList();
    final alerts = actions.where((a) => a.id == 'alerta_general').toList();
    return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
      Row(children: [Image.asset('assets/logo_saunastilo.png', width: 130, height: 48, fit: BoxFit.contain), const Spacer(), for (final id in ['avisos', 'configuracion']) IconButton(tooltip: actions.firstWhere((a) => a.id == id).title, onPressed: () => _open(actions.firstWhere((a) => a.id == id)), icon: Icon(id == 'avisos' ? Icons.notifications_none_rounded : Icons.tune_rounded))]),
      const SizedBox(height: 15),
      Text('Hola, ${widget.usuario.nombre.split(' ').first}', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.7)),
      const SizedBox(height: 5),
      const Text('Tu jornada. Tus proyectos. Tu equipo.', style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 18),
      if (alerts.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF647A), backgroundColor: const Color(0xFF240B12), side: const BorderSide(color: Color(0xFF8E1538)), minimumSize: const Size.fromHeight(54)), onPressed: () => _open(alerts.first), icon: const Icon(Icons.campaign_rounded), label: const Text('ALERTA GENERAL · TODO EL EQUIPO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))),
      HomeProgressPanel(user: widget.usuario, onStreak: () => _open(actions.firstWhere((a) => a.id == (widget.usuario.rol == AppRoles.admin ? 'rachas' : 'racha'))), onProfile: () => widget.onTab(4), onLearn: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrainingAccessScreen(user: widget.usuario)))),
      if (widget.usuario.rol == AppRoles.admin)
        AdminOperationsCard(onAttendance: () => _open(actions.firstWhere((a) => a.id == 'asistencias')), onTeam: () => _open(actions.firstWhere((a) => a.id == 'equipo')))
      else JornadaCompacta(usuario: widget.usuario),
      const SizedBox(height: 16),
      Row(children: [const Expanded(child: Text('Mis tareas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), TextButton(onPressed: () => widget.onTab(3), child: const Text('Ver todas'))]),
      OperationsTaskList(usuario: widget.usuario, compact: true),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => widget.onTab(2), icon: const Icon(Icons.contact_phone_outlined), label: const Text('Llamar o escribir a una persona'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: quick.map((a) => ActionChip(shape: const StadiumBorder(), side: BorderSide(color: stiloAccents[quick.indexOf(a) % stiloAccents.length].withOpacity(.34)), avatar: Icon(a.icon, size: 18, color: stiloAccents[quick.indexOf(a) % stiloAccents.length]), label: Text(a.id == 'ia' ? 'Online Smart' : a.title), onPressed: () => _open(a))).toList()),
      const SizedBox(height: 20),
      TextField(contextMenuBuilder: privacyTextMenu, decoration: const InputDecoration(hintText: 'Buscar una opción…', prefixIcon: Icon(Icons.search_rounded)), onChanged: (value) => setState(() => _search = value)),
      TextButton.icon(onPressed: () => setState(() => _all = !_all), icon: Icon(_all ? Icons.expand_less_rounded : Icons.apps_rounded), label: Text(_all ? 'Cerrar menú completo' : 'Todas las opciones de mi cuenta')),
      if (_all || _search.trim().isNotEmpty) ...actions.where((a) => a.matches(_search)).map((a) => Card(color: const Color(0xFF111012), child: ListTile(leading: Icon(a.icon, color: a.color), title: Text(a.id == 'ia' ? 'Online Smart' : a.title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(a.id == 'ia' ? 'Asistente mexicano para tus actividades' : a.subtitle), trailing: const Icon(Icons.arrow_forward_rounded, size: 18), onTap: () => _open(a)))),
    ]));
  }
}

class OperationsTaskList extends StatelessWidget {
  final UserModel usuario;
  final bool compact;
  const OperationsTaskList({super.key, required this.usuario, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final admin = usuario.rol == AppRoles.admin;
    final query = admin ? FirebaseFirestore.instance.collection('actividades') : FirebaseFirestore.instance.collection('actividades').where('asignadoATrabajadorId', isEqualTo: usuario.id);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.snapshots(), builder: (context, snapshot) {
      if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(16), child: Text('No pudimos consultar las tareas. Revisa conexión y permisos.', style: TextStyle(color: Colors.orangeAccent)));
      if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
      final tasks = snapshot.data!.docs.map((d) => ActividadModel.fromJson(d.data(), d.id)).where((a) => !compact || a.estatus != 'completado').toList()..sort((a,b) => a.fechaTermino.compareTo(b.fechaTermino));
      if (tasks.isEmpty) return Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF111012), borderRadius: BorderRadius.circular(20)), child: const Text('No hay tareas pendientes en esta vista.', style: TextStyle(color: Colors.white60)));
      return Column(children: (compact ? tasks.take(4) : tasks).map((task) => Card(color: const Color(0xFF111012), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), leading: Icon(task.estatus == 'completado' ? Icons.task_alt_rounded : Icons.assignment_outlined, color: const Color(0xFFB7FF2A)), title: Text(task.titulo, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${DateFormat('dd/MM HH:mm').format(task.fechaTermino)} · ${task.estatus.replaceAll('_', ' ')}'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => admin ? admin_detail.ModalDetalleActividad(actividad: task) : worker_detail.ModalDetalleActividad(actividad: task))))).toList());
    });
  }
}
