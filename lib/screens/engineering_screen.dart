import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import '../widgets/jornada_compacta.dart';
import '../widgets/stilo_orbit.dart';
import 'admin_solicitudes_herramientas_screen.dart';
import 'extra_work_screen.dart';
import 'inventario_trabajador_screen.dart';

const engineeringCategories = {'produccion': 'Producción', 'calidad': 'Calidad', 'tiempos': 'Tiempos', 'mejora': 'Mejora continua'};
const engineeringStates = {'pendiente': 'Pendiente', 'en_proceso': 'En proceso', 'cerrado': 'Cerrado'};

class EngineeringScreen extends StatefulWidget {
  final UserModel user;
  final bool embedded;
  final VoidCallback? onOptions;
  const EngineeringScreen({super.key, required this.user, this.embedded = false, this.onOptions});
  @override State<EngineeringScreen> createState() => _EngineeringState();
}
class _EngineeringState extends State<EngineeringScreen> {
  final service = CompanyLearningService();
  DateTime day = staffToday();
  List<Map<String, dynamic>>? records;
  bool busy = false;
  String? error;
  @override void initState() { super.initState(); if (widget.user.rol == AppRoles.admin || widget.user.panelIngenieria) _load(); }
  Future<void> _load() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try { final r = await service.call('engineering-list', {'date': staffDate(day)}); if (mounted) setState(() => records = (r['items'] as List).map((v) => Map<String, dynamic>.from(v)).toList()); }
    catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _change(Map<String, dynamic> r) async {
    final note = TextEditingController(); String status = r['status'];
    final yes = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, update) => AlertDialog(title: Text(r['title']), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(r['description'] ?? ''), const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: status, items: engineeringStates.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) update(() => status = v); }, decoration: const InputDecoration(labelText: 'Seguimiento')),
      TextField(contextMenuBuilder: privacyTextMenu, controller: note, maxLength: 1200, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Avance o conclusión')),
      for (final h in (r['history'] as List? ?? [])) ListTile(title: Text(engineeringStates[h['status']] ?? h['status']), subtitle: Text('${h['comment']}\n${h['actorName']} · ${h['at']}')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cerrar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar avance'))])));
    final comment = note.text.trim(); note.dispose();
    if (yes != true || !mounted) return;
    if (comment.isEmpty) { setState(() => error = 'Describe el avance antes de guardarlo.'); return; }
    setState(() => busy = true);
    try { await service.call('engineering-update', {'date': staffDate(day), 'id': r['id'], 'status': status, 'comment': comment, 'operationId': const Uuid().v4()}); }
    catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => busy = false); }
    if (mounted && error == null) await _load();
  }
  @override Widget build(BuildContext context) {
    if (widget.user.rol != AppRoles.admin && !widget.user.panelIngenieria) return const Scaffold(body: Center(child: Text('Ingeniería requiere autorización de Administración.')));
    final list = records ?? <Map<String, dynamic>>[];
    final content = SafeArea(bottom: false, child: RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
      if (widget.embedded) Row(children: [Image.asset('assets/logo_saunastilo.png', width: 128, height: 48), const Spacer(), IconButton(tooltip: 'Todas mis opciones', onPressed: widget.onOptions, icon: const Icon(Icons.apps_rounded))]),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [Color(0xFF351326), Color(0xFF13121B)]), border: Border.all(color: const Color(0xFF6E4069))), child: Row(children: [const StiloOrbitIcon(icon: Icons.precision_manufacturing_rounded, color: Color(0xFFC798FF), size: 54, active: true), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hola, ${widget.user.nombre.split(' ').first}', style: const TextStyle(color: Colors.white60)), const Text('Ingeniería industrial', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('Producción · calidad · tiempos · mejoras', style: TextStyle(fontSize: 12, color: Colors.white60))]))])),
      if (widget.embedded && widget.user.rol != AppRoles.admin) Padding(padding: const EdgeInsets.only(top: 14), child: JornadaCompacta(usuario: widget.user)),
      const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [Chip(avatar: const Icon(Icons.analytics_rounded), label: Text('${list.length} registros')), Chip(avatar: const Icon(Icons.verified_rounded, color: Color(0xFFB7FF2A)), label: Text('${list.where((r) => r['status'] == 'cerrado').length} cerrados'))]),
      OutlinedButton.icon(onPressed: busy ? null : () async { final d = await showDatePicker(context: context, initialDate: day, firstDate: DateTime(2020), lastDate: DateTime(2099)); if (d != null && mounted) { setState(() { day = d; records = null; }); await _load(); } }, icon: const Icon(Icons.event_rounded), label: Text('Fecha · ${staffDate(day)}')),
      FilledButton.icon(onPressed: busy ? null : () async { await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => EngineeringForm(date: day, service: service))); if (mounted) await _load(); }, icon: const Icon(Icons.add_chart_rounded), label: const Text('Registrar medición o mejora')),
      OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ['admin', 'almacenista'].contains(widget.user.rol) ? const AdminSolicitudesHerramientasScreen() : const InventarioTrabajadorScreen())), icon: const Icon(Icons.handyman_rounded, color: Color(0xFFFFB876)), label: Text(['admin', 'almacenista'].contains(widget.user.rol) ? 'Gestionar herramientas y préstamos' : 'Consultar herramientas')),
      if (busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
      if (!busy && error == null && records != null && list.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No hay registros para esta fecha.')),
      for (final r in list) Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: StiloOrbitIcon(icon: r['category'] == 'calidad' ? Icons.verified_rounded : r['category'] == 'tiempos' ? Icons.timer_rounded : Icons.factory_rounded, color: const Color(0xFFC798FF), size: 42), title: Text(r['title'], style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${engineeringCategories[r['category']]} · ${engineeringStates[r['status']]}\n${r['project']} · Responsable: ${r['responsible']}\nUnidades: ${r['actual']}/${r['planned']} · Rechazadas: ${r['rejected']}\nMinutos: ${r['actualMinutes']}/${r['plannedMinutes']}', style: const TextStyle(height: 1.5)), trailing: const Icon(Icons.chevron_right_rounded), onTap: busy ? null : () => _change(r))),
      const Padding(padding: EdgeInsets.only(top: 16), child: Text('Las mediciones no cambian los porcentajes de proyectos ni la asistencia. El historial identifica quién registró cada avance.', style: TextStyle(color: Colors.white54, fontSize: 12))),
      if (widget.embedded) TextButton.icon(onPressed: widget.onOptions, icon: const Icon(Icons.apps_rounded), label: const Text('Rachas, insignias, idiomas y todas mis opciones')),
    ])));
    return widget.embedded ? content : Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Ingeniería industrial'), actions: [IconButton(tooltip: 'Actualizar', onPressed: busy ? null : _load, icon: const Icon(Icons.refresh_rounded))]), body: content);
  }
}
class EngineeringForm extends StatefulWidget {
  final DateTime date; final CompanyLearningService service;
  const EngineeringForm({super.key, required this.date, required this.service});
  @override State<EngineeringForm> createState() => _EngineeringFormState();
}
class _EngineeringFormState extends State<EngineeringForm> {
  final fields = {for (final k in ['title', 'project', 'description', 'responsible', 'planned', 'actual', 'rejected', 'plannedMinutes', 'actualMinutes']) k: TextEditingController()};
  String category = 'produccion'; bool busy = false; String? error, op, fingerprint;
  @override void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  Future<void> _save() async {
    if (busy) return;
    final data = <String, dynamic>{'date': staffDate(widget.date), 'category': category, 'status': 'pendiente'};
    for (final e in fields.entries) {
      if (['title', 'project', 'description', 'responsible'].contains(e.key)) { data[e.key] = e.value.text.trim(); }
      else { final value = e.value.text.trim().isEmpty ? 0.0 : double.tryParse(e.value.text.replaceAll(',', '.')); if (value == null || !value.isFinite || value < 0 || value > 1e7) { setState(() => error = 'Revisa las mediciones: deben ser números no negativos.'); return; } data[e.key] = value; }
    }
    if ((data['title'] as String).isEmpty || data['rejected'] > data['actual']) { setState(() => error = 'Escribe un título y revisa las unidades rechazadas.'); return; }
    if (fingerprint != data.toString()) { fingerprint = data.toString(); op = const Uuid().v4(); }
    setState(() { busy = true; error = null; });
    try { await widget.service.call('engineering-create', {...data, 'operationId': op}); if (mounted) Navigator.pop(context); }
    catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => PopScope(canPop: !busy, child: Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Nuevo registro de Ingeniería')), body: ListView(padding: const EdgeInsets.all(20), children: [
    DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Área'), items: engineeringCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: busy ? null : (v) { if (v != null) setState(() => category = v); }),
    for (final e in const {'title': 'Título', 'project': 'Proyecto o proceso', 'description': 'Observaciones y propuesta', 'responsible': 'Responsable', 'planned': 'Unidades planeadas', 'actual': 'Unidades realizadas', 'rejected': 'Unidades rechazadas', 'plannedMinutes': 'Minutos planeados', 'actualMinutes': 'Minutos reales'}.entries) Padding(padding: const EdgeInsets.only(top: 12), child: TextField(contextMenuBuilder: privacyTextMenu, controller: fields[e.key], enabled: !busy, maxLength: e.key == 'description' ? 2400 : 120, minLines: e.key == 'description' ? 3 : 1, maxLines: e.key == 'description' ? 5 : 1, keyboardType: ['planned', 'actual', 'rejected', 'plannedMinutes', 'actualMinutes'].contains(e.key) ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: e.value))),
    if (error != null) Text(error!, style: const TextStyle(color: Colors.orangeAccent)), FilledButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(busy ? 'Guardando…' : 'Guardar registro')),
  ])));
}

class EngineeringAccessControl extends StatefulWidget {
  final UserModel administrator; final String profileId; final Map<String, dynamic> profile;
  const EngineeringAccessControl({super.key, required this.administrator, required this.profileId, required this.profile});
  @override State<EngineeringAccessControl> createState() => _EngineeringAccessState();
}
class _EngineeringAccessState extends State<EngineeringAccessControl> {
  bool busy = false; String? error;
  Future<void> _change(String field, bool enabled) async {
    if (busy || widget.administrator.rol != AppRoles.admin) return;
    final warehouse = field == 'warehouse';
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(warehouse ? '¿Cambiar permiso operativo de Almacén?' : '¿Cambiar el panel de Ingeniería?'), content: Text(warehouse ? 'Este permiso usa el rol de Almacén existente para registrar herramientas, aprobar salidas y confirmar recepciones. No otorga acceso administrativo a ventas, cuentas ni salarios. Revisa la persona seleccionada.' : 'Cambia su Inicio y permite registrar producción, calidad, tiempos y mejoras. No le da acceso a las cuentas de otras personas ni cambia su asistencia.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar'))]));
    if (yes != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      final db = FirebaseFirestore.instance, ref = FirebaseFirestore.instance.collection('usuarios').doc(widget.profileId);
      await db.runTransaction((tx) async {
        final s = await tx.get(ref), d = s.data();
        if (d == null || d['activo'] == false) throw StateError('Cuenta inactiva.');
        if (!warehouse) { tx.update(ref, {'panelIngenieria': enabled}); return; }
        if (d['rol'] == 'admin' || d['panelIngenieria'] != true) throw StateError('Selecciona una cuenta de Ingeniería sin rol de Administración.');
        if (enabled) { if (d['rol'] != 'almacenista') tx.update(ref, {'rol': 'almacenista', 'rolPrevioIngenieria': d['rol'], 'almacenPorIngenieria': true}); }
        else { if (d['almacenPorIngenieria'] != true) throw StateError('El rol de Almacén fue asignado por otra vía; revísalo en Gestión de usuarios.'); final previous = d['rolPrevioIngenieria']; if (!['trabajador', 'maestro'].contains(previous)) throw StateError('Revisa el rol anterior en Gestión de usuarios.'); tx.update(ref, {'rol': previous, 'almacenPorIngenieria': false}); }
      });
    } catch (e) { if (mounted) setState(() => error = e is StateError ? e.message.toString() : 'No se confirmó el cambio. Revisa permisos y conexión.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) {
    if (widget.administrator.rol != AppRoles.admin) return const SizedBox.shrink();
    return Card(child: Column(children: [
      SwitchListTile(secondary: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFFC798FF)), title: const Text('Panel de Ingeniería'), subtitle: const Text('Producción, calidad, tiempos y mejoras'), value: widget.profile['panelIngenieria'] == true, onChanged: busy ? null : (v) => _change('panel', v)),
      if (widget.profile['panelIngenieria'] == true && widget.profile['rol'] != 'admin') SwitchListTile(title: const Text('Gestión operativa de Almacén'), subtitle: const Text('Usa el rol de Almacén; no concede Administración completa.'), value: widget.profile['rol'] == 'almacenista', onChanged: busy ? null : (v) => _change('warehouse', v)),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
    ]));
  }
}
