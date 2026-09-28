import '../presentation/appearance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import '../widgets/stilo_orbit.dart';
import 'admin_asistencias_screen.dart';
import 'admin_solicitudes_herramientas_screen.dart';
import 'extra_work_screen.dart';
import 'training_access_screen.dart';

/// Reads actual requests independently from phone notification delivery.
class AdminInboxScreen extends StatefulWidget {
  final UserModel user;
  const AdminInboxScreen({super.key, required this.user});
  @override State<AdminInboxScreen> createState() => _AdminInboxState();
}
class _AdminInboxState extends State<AdminInboxScreen> {
  final service = CompanyLearningService();
  List<Map<String, dynamic>> people = [], training = [], extras = [];
  int page = 0;
  bool busy = false, loaded = false;
  String? error;
  DateTime date = staffToday();
  @override void initState() { super.initState(); if (widget.user.rol == AppRoles.admin) _load(); }
  Future<void> _load({bool reloadPeople = false}) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      if (people.isEmpty || reloadPeople) {
        final result = await FirebaseFirestore.instance.collection('usuarios').get(GetOptions(source: Source.server));
        people = result.docs.where((d) => d.data()['activo'] != false).map((d) => <String, dynamic>{'id': d.id, 'name': d.data()['nombre']?.toString() ?? 'Integrante'}).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        if (page * 8 >= people.length) page = 0;
      }
      final ids = people.skip(page * 8).take(8).map((p) => p['id'] as String).toList();
      if (ids.isEmpty) { if (mounted) setState(() { training = []; extras = []; loaded = true; }); return; }
      final t = await service.call('training-inbox', {'userIds': ids});
      if (mounted) setState(() => training = (t['items'] as List).map((v) => Map<String, dynamic>.from(v)).toList());
      final e = await service.call('extra-inbox', {'userIds': ids, 'date': staffDate(date)});
      if (mounted) setState(() { extras = (e['items'] as List).map((v) => Map<String, dynamic>.from(v)).toList(); loaded = true; });
    } catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  String _name(String uid) => people.firstWhere((p) => p['id'] == uid, orElse: () => <String, dynamic>{'name': 'Integrante'})['name'].toString();
  Future<void> _review(Map<String, dynamic> r) async {
    final comment = TextEditingController(); bool accept = true;
    final yes = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, change) => AlertDialog(title: Text(r['title']), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(r['description']), SizedBox(height: 10), SwitchListTile(value: accept, onChanged: (v) => change(() => accept = v), title: Text(accept ? 'Reconocer reporte' : 'Solicitar aclaración')),
      TextField(contextMenuBuilder: privacyTextMenu, controller: comment, maxLength: 1000, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'Comentario de revisión')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('Guardar revisión'))])));
    final text = comment.text.trim(); comment.dispose();
    if (yes != true || !mounted) return;
    if (text.length < 3) { setState(() => error = 'Agrega un comentario antes de revisar.'); return; }
    setState(() => busy = true);
    try { await service.call('extra-review', {'userId': r['userId'], 'date': staffDate(date), 'id': r['id'], 'accepted': accept, 'comment': text, 'operationId': Uuid().v4()}); }
    catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => busy = false); }
    if (mounted && error == null) await _load();
  }
  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen)).then((_) { if (mounted) _load(); });
  @override Widget build(BuildContext context) {
    Theme.of(context);
    if (widget.user.rol != AppRoles.admin) return Scaffold(body: Center(child: Text('Solo Administración.')));
    return Scaffold(backgroundColor: StiloColors.background, appBar: AppBar(title: Text('Bandeja de Administración'), actions: [IconButton(tooltip: 'Actualizar solicitudes', onPressed: busy ? null : () => _load(reloadPeople: true), icon: Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(onRefresh: () => _load(reloadPeople: true), child: ListView(physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.all(18), children: [
        Text('Todo por revisar, en un lugar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 9),
        Text('Las solicitudes se consultan aquí aunque el teléfono no haya recibido una notificación. Nunca se aprueban automáticamente.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60), height: 1.5)),
        SizedBox(height: 18),
        _FirestoreInboxCard(query: FirebaseFirestore.instance.collection('solicitudes_herramientas').where('estatus', isEqualTo: 'pendiente'), title: 'Herramientas por autorizar', icon: Icons.handyman_rounded, color: StiloColors.accent, describe: (d) => '${d['trabajadorNombre'] ?? 'Integrante'} · ${d['nombreInsumo'] ?? 'Herramienta'}', open: () => _open(AdminSolicitudesHerramientasScreen())),
        _FirestoreInboxCard(query: FirebaseFirestore.instance.collection('solicitudes_herramientas').where('marcadoDevueltoTrabajador', isEqualTo: true), title: 'Devoluciones por recibir', pendingFilter: (d) => d['devueltoConfirmadoAdmin'] != true, icon: Icons.move_to_inbox_rounded, color: Color(0xFFFFB876), describe: (d) => '${d['trabajadorNombre'] ?? 'Integrante'} · ${d['nombreInsumo'] ?? 'Herramienta'}', open: () => _open(AdminSolicitudesHerramientasScreen())),
        _FirestoreInboxCard(query: FirebaseFirestore.instance.collection('asistencias').where('estatusComida', isEqualTo: 'pendiente_aprobacion'), title: 'Hora de comida por aprobar', icon: Icons.restaurant_rounded, color: Color(0xFFFF729C), describe: (d) => _name(d['trabajadorId']?.toString() ?? ''), open: () => _open(AdminAsistenciasScreen(nombreAdmin: widget.user.nombre))),
        SizedBox(height: 18), Text('Idiomas y contribuciones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Row(children: [IconButton(tooltip: 'Página anterior', onPressed: busy || page == 0 ? null : () { setState(() { page--; loaded = false; training = []; extras = []; }); _load(); }, icon: Icon(Icons.chevron_left_rounded)), Expanded(child: Text('Personas ${people.isEmpty ? 0 : page * 8 + 1}–${((page + 1) * 8).clamp(0, people.length)} de ${people.length}', textAlign: TextAlign.center)), IconButton(tooltip: 'Siguiente página', onPressed: busy || (page + 1) * 8 >= people.length ? null : () { setState(() { page++; loaded = false; training = []; extras = []; }); _load(); }, icon: Icon(Icons.chevron_right_rounded))]),
        Text('Se revisan ocho cuentas por página para no saturar el servicio. Cambia de página para consultar el resto del equipo.', style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 11)),
        if (busy) Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        if (error != null) Padding(padding: EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Colors.orangeAccent))),
        if (loaded && error == null && training.isEmpty) ListTile(title: Text('Sin solicitudes de idiomas en esta página')),
        for (final r in training) Card(child: ListTile(leading: StiloOrbitIcon(icon: Icons.school_rounded, color: StiloColors.accent, size: 42), title: Text(_name(r['userId'])), subtitle: Text('${r['language'] == 'en' ? 'Inglés' : 'Francés'} · ${r['kind'] == 'certificate' ? 'Revisar constancia' : 'Solicita acceso'}'), trailing: Icon(Icons.chevron_right_rounded), onTap: () => _open(TrainingAdminScreen(user: widget.user, initialUserId: r['userId'], initialName: _name(r['userId']))))),
        SizedBox(height: 14), OutlinedButton.icon(onPressed: busy ? null : () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: staffToday()); if (d != null && mounted) { setState(() { date = d; extras = []; loaded = false; }); await _load(); } }, icon: Icon(Icons.event_rounded), label: Text('Trabajo extra y faltantes · ${staffDate(date)}')),
        if (loaded && error == null && extras.isEmpty) ListTile(title: Text('Sin reportes en esta fecha y página')),
        for (final r in extras) Card(child: ListTile(leading: Icon(r['category'] == 'faltante' ? Icons.shopping_basket_rounded : Icons.auto_awesome_rounded, color: Color(0xFFFFB876)), title: Text('${_name(r['userId'])} · ${r['title']}'), subtitle: Text('${r['description']}\n${(r['status'] as String).replaceAll('_', ' ')}', maxLines: 4, overflow: TextOverflow.ellipsis), trailing: Icon(Icons.rate_review_rounded), onTap: busy ? null : () => _review(r))),
      ])));
  }
}
class _FirestoreInboxCard extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final String title; final IconData icon; final Color color;
  final String Function(Map<String, dynamic>) describe;
  final VoidCallback open;
  final bool Function(Map<String, dynamic>)? pendingFilter;
  _FirestoreInboxCard({required this.query, required this.title, required this.icon, required this.color, required this.describe, required this.open, this.pendingFilter});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [StiloOrbitIcon(icon: icon, color: color, size: 42, active: true), SizedBox(width: 12), Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)))]),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: query.limit(100).snapshots(includeMetadataChanges: true), builder: (c, s) {
      if (s.hasError) return Padding(padding: EdgeInsets.all(10), child: Text('No se pudieron consultar estas solicitudes. Revisa conexión y permisos; las demás secciones siguen disponibles.', style: TextStyle(color: Colors.orangeAccent)));
      if (!s.hasData) return LinearProgressIndicator();
      final pending = s.data!.docs.where((d) => pendingFilter?.call(d.data()) ?? true).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('${pending.length} pendientes en esta consulta${s.data!.docs.length == 100 ? ' · abre para revisar el historial completo' : ''}${s.data!.metadata.isFromCache ? ' · copia local' : ''}', style: TextStyle(color: color, fontWeight: FontWeight.w800)), for (final d in pending.take(3)) Padding(padding: EdgeInsets.only(top: 6), child: Text(describe(d.data()), style: TextStyle(color: StiloColors.text.withValues(alpha: .70))))]);
    }), TextButton.icon(onPressed: open, icon: Icon(Icons.arrow_forward_rounded), label: Text('Abrir y revisar')),
  ])));
}
