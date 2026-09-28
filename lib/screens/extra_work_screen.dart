import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/company_learning_service.dart';
import '../services/external_transfer.dart';
import '../widgets/stilo_orbit.dart';

String staffDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime staffToday() { final d = DateTime.now().toUtc().subtract(Duration(hours: 6)); return DateTime(d.year, d.month, d.day); }

class ExtraWorkScreen extends StatefulWidget {
  final UserModel user;
  final CompanyLearningService? service;
  const ExtraWorkScreen({super.key, required this.user, this.service});
  @override State<ExtraWorkScreen> createState() => _ExtraWorkState();
}
class _ExtraWorkState extends State<ExtraWorkScreen> {
  late final service = widget.service ?? CompanyLearningService();
  DateTime date = staffToday();
  List<Map<String, dynamic>>? items;
  String? error;
  bool loading = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try { final r = await service.call('extra-list', {'date': staffDate(date)}); if (mounted) setState(() => items = (r['items'] as List).map((v) => Map<String, dynamic>.from(v)).toList()); }
    catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> _new() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExtraWorkForm(date: date, service: service)));
    if (mounted) await _load();
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: StiloColors.background,
    appBar: AppBar(title: Text('Lo que hice de más'), actions: [IconButton(tooltip: 'Actualizar reportes', onPressed: loading ? null : _load, icon: Icon(Icons.refresh_rounded))]),
    body: RefreshIndicator(onRefresh: _load, child: ListView(physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.all(20), children: [
      StiloOrbitIcon(icon: Icons.auto_awesome_rounded, color: Color(0xFFFFB876), size: 56, active: true),
      SizedBox(height: 14), Text('Tu esfuerzo también cuenta', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      SizedBox(height: 9), Text('Registra trabajo extra ya realizado o un faltante detectado. Administración lo revisará. Esto no agrega tareas asignadas, compras ni horas de asistencia.', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.5)),
      SizedBox(height: 16), OutlinedButton.icon(onPressed: loading ? null : () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: staffToday()); if (d != null && mounted) { setState(() { date = d; items = null; }); await _load(); } }, icon: Icon(Icons.event_rounded), label: Text(DateFormat('dd/MM/yyyy').format(date))),
      FilledButton.icon(onPressed: loading ? null : _new, icon: Icon(Icons.post_add_rounded), label: Text('Reportar actividad extra o faltante')),
      if (loading) Padding(padding: EdgeInsets.all(14), child: LinearProgressIndicator()),
      if (error != null) Padding(padding: EdgeInsets.all(14), child: Text(error!, style: TextStyle(color: Colors.orangeAccent))),
      if (items != null && items!.isEmpty) Padding(padding: EdgeInsets.all(20), child: Text('Todavía no hay reportes de esta fecha.')),
      for (final r in items ?? <Map<String, dynamic>>[]) Card(child: Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(r['category'] == 'faltante' ? Icons.shopping_basket_outlined : Icons.task_alt_rounded, color: Color(0xFFFFB876)), SizedBox(width: 10), Expanded(child: Text(r['title'], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)))]),
        SizedBox(height: 10), Text(r['description'], style: TextStyle(height: 1.45)), SizedBox(height: 10), Text((r['status'] as String).replaceAll('_', ' '), style: TextStyle(color: StiloColors.accent)),
        if (r['review'] != null) Text('${r['reviewer']}: ${r['review']}', style: TextStyle(color: StiloColors.text.withValues(alpha: .60))),
      ]))),
    ])));
}

class ExtraWorkForm extends StatefulWidget {
  final DateTime date;
  final CompanyLearningService service;
  const ExtraWorkForm({super.key, required this.date, required this.service});
  @override State<ExtraWorkForm> createState() => _ExtraFormState();
}
class _ExtraFormState extends State<ExtraWorkForm> {
  final title = TextEditingController(), description = TextEditingController(), minutes = TextEditingController();
  String category = 'extra'; String? error, operation, fingerprint;
  bool confirmed = false, busy = false;
  @override void dispose() { title.dispose(); description.dispose(); minutes.dispose(); super.dispose(); }
  Future<void> _send() async {
    if (busy) return;
    final m = minutes.text.trim().isEmpty ? 0 : int.tryParse(minutes.text.trim());
    if (!confirmed || title.text.trim().isEmpty || description.text.trim().length < 8 || m == null || m < 0 || m > 1440) { setState(() => error = 'Completa el título, la descripción y la confirmación. Usa minutos válidos.'); return; }
    final payload = {'date': staffDate(widget.date), 'category': category, 'title': title.text.trim(), 'description': description.text.trim(), 'minutes': m, 'performed': true};
    if (fingerprint != payload.toString()) { fingerprint = payload.toString(); operation = Uuid().v4(); }
    setState(() { busy = true; error = null; });
    try {
      await widget.service.call('extra-create', {...payload, 'operationId': operation});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reporte confirmado y disponible para Administración. No se creó una tarea ni una compra.'))); Navigator.pop(context); }
    } catch (e) { if (mounted) setState(() => error = CompanyLearningService.message(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => PopScope(canPop: !busy, child: Scaffold(backgroundColor: StiloColors.background, appBar: AppBar(title: Text('Nuevo reporte')), body: ListView(padding: EdgeInsets.all(20), children: [
    Text('Reporta, no te asignes', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
    SizedBox(height: 10), Text('Las instrucciones y asignaciones las administra tu responsable. Aquí dejas constancia de una contribución adicional o de algo que falta.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60), height: 1.5)),
    SizedBox(height: 16), Wrap(spacing: 10, children: [ChoiceChip(label: Text('Trabajo extra'), selected: category == 'extra', onSelected: busy ? null : (_) => setState(() => category = 'extra')), ChoiceChip(label: Text('Faltante'), selected: category == 'faltante', onSelected: busy ? null : (_) => setState(() => category = 'faltante'))]),
    SizedBox(height: 12), TextField(contextMenuBuilder: privacyTextMenu, controller: title, enabled: !busy, maxLength: 160, decoration: InputDecoration(labelText: '¿Qué hiciste o qué detectaste?')),
    TextField(contextMenuBuilder: privacyTextMenu, controller: description, enabled: !busy, minLines: 4, maxLines: 8, maxLength: 3000, decoration: InputDecoration(labelText: 'Detalles y resultado', alignLabelWithHint: true)),
    if (category == 'extra') TextField(controller: minutes, enabled: !busy, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Minutos aproximados (opcional)')),
    CheckboxListTile(value: confirmed, onChanged: busy ? null : (v) => setState(() => confirmed = v == true), title: Text('Confirmo que el reporte corresponde a algo ya realizado o detectado.')),
    if (error != null) Padding(padding: EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Colors.orangeAccent))),
    FilledButton.icon(onPressed: busy ? null : _send, icon: Icon(Icons.send_rounded), label: Text(busy ? 'Enviando…' : 'Enviar para revisión')),
  ])));
}
