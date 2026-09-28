import '../presentation/appearance.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/attendance_gateway_service.dart';
import '../services/company_learning_service.dart';
import '../workflow/staff_policy.dart';
import 'modal_asignar_actividades.dart';

String _operation() => '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class DailyTasksScreen extends StatefulWidget {
  final UserModel user;
  final DateTime? day;
  final bool embedded;
  final CompanyLearningService? service;
  const DailyTasksScreen({super.key, required this.user, this.day, this.service, this.embedded = false});
  @override State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> with WidgetsBindingObserver {
  late final CompanyLearningService _service = widget.service ?? CompanyLearningService();
  late DateTime _day = widget.day ?? AttendanceGatewayService.today;
  List<Map<String, dynamic>> _items = [];
  Timer? _timer;
  bool _busy = false;
  String? _error;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); unawaited(_load());
    _timer = Timer.periodic(Duration(seconds: 45), (_) => unawaited(_load()));
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }
  Future<void> _load() async {
    if (_busy) return;
    final day = AttendanceGatewayService.dayKey(_day);
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _service.call('daily-list', {'day': day});
      if (mounted && day == AttendanceGatewayService.dayKey(_day)) setState(() => _items = (response['items'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList());
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); }
    finally { if (mounted) { setState(() => _busy = false); if (day != AttendanceGatewayService.dayKey(_day)) unawaited(_load()); } }
  }
  Future<void> _create() async {
    if (!canAssignWork(widget.user.rol)) return;
    await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ModalAsignarActividad(proyectoId: '', rolUsuario: widget.user.rol, initialDay: _day));
    if (mounted) await _load();
  }
  @override void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: Text('Tareas del día'), actions: [IconButton(tooltip: 'Actualizar tareas', onPressed: _busy ? null : _load, icon: Icon(Icons.refresh))]),
    floatingActionButton: canAssignWork(widget.user.rol) ? FloatingActionButton.extended(onPressed: _create, icon: Icon(Icons.add_task), label: Text('Asignar tarea')) : null,
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      OutlinedButton.icon(onPressed: () async {
        final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime(2035));
        if (picked != null && mounted) { setState(() { _day = picked; _items = []; }); await _load(); }
      }, icon: Icon(Icons.today), label: Text(DateFormat('dd/MM/yyyy').format(_day))),
      SizedBox(height: 12),
      Text(canAssignWork(widget.user.rol) ? 'Asigna a cualquier perfil activo. Aquí puedes revisar las entregas y sus evidencias.' : 'Abre tu tarea para adjuntar evidencia y entregar el trabajo.', style: TextStyle(color: StiloColors.text.withValues(alpha: .70))),
      if (_busy) Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
      if (_error != null) Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), TextButton.icon(onPressed: _busy ? null : _load, icon: Icon(Icons.refresh), label: Text('Volver a intentar'))]))),
      if (!_busy && _error == null && _items.isEmpty) Padding(padding: EdgeInsets.all(24), child: Text('No tienes tareas del día en esta fecha.')),
      for (final task in _items) Card(child: ListTile(
        title: Text(task['title'] as String, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${task['userName']} · ${task['status']}\n${task['evidenceCount']} evidencias · Asignó ${task['createdByName']}'),
        leading: Icon(task['status'] == 'completado' ? Icons.task_alt : Icons.assignment_outlined, color: StiloColors.accent),
        trailing: Icon(Icons.chevron_right), onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DailyTaskDetail(user: widget.user, task: task, service: _service)));
          if (mounted) await _load();
        },
      )),
    ])),
  );
}

class DailyTaskDetail extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic> task;
  final CompanyLearningService? service;
  const DailyTaskDetail({super.key, required this.user, required this.task, this.service});
  @override State<DailyTaskDetail> createState() => _DailyTaskDetailState();
}
class _DailyTaskDetailState extends State<DailyTaskDetail> {
  late final CompanyLearningService _service = widget.service ?? CompanyLearningService();
  late Map<String, dynamic> _task = {...widget.task};
  final _comment = TextEditingController();
  final _operations = <String, String>{};
  bool _busy = false, _ready = false;
  String? _error, _pendingName;
  Uint8List? _pendingBytes;
  bool get _own => widget.user.id == _task['userId'];
  Map<String, dynamic> get _reference => {'day': _task['day'], 'taskId': _task['taskId']};
  @override void initState() { super.initState(); unawaited(_load()); }
  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _service.call('daily-read', _reference);
      if (mounted) setState(() { _task = Map<String, dynamic>.from(response['task'] as Map); _ready = true; });
    } catch (error) { if (mounted) setState(() { _error = CompanyLearningService.message(error); _ready = false; }); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<bool> _send(String action, [Map<String, dynamic> data = const {}]) async {
    if (_busy || !_ready) return false;
    final operationKey = '$action:${jsonEncode(data)}';
    final operationId = _operations.putIfAbsent(operationKey, _operation);
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _service.call(action, {..._reference, ...data, 'operationId': operationId});
      if (response['saved'] != true) throw StateError('No se confirmó el guardado.');
      if (!mounted) return false;
      setState(() => _task = Map<String, dynamic>.from(response['task'] as Map));
      _operations.remove(operationKey);
      return true;
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); return false; }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _pick({bool camera = false}) async {
    if (_busy) return;
    try {
      Uint8List? bytes; String? name;
      if (camera) {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
        if (photo == null) return;
        bytes = await photo.readAsBytes(); name = photo.name;
      } else {
        final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'], allowMultiple: false);
        if (files.isEmpty) return;
        final file = files.single;
        if (await file.length() > 2 * 1024 * 1024) throw StateError('El archivo debe pesar como máximo 2 MB.');
        bytes = await file.readAsBytes(); name = file.name;
      }
      if (bytes == null || bytes.isEmpty || bytes.length > 2 * 1024 * 1024) throw StateError('Elige una foto o PDF de hasta 2 MB. Puedes usar Tomar foto para reducir su tamaño.');
      if (mounted) setState(() { _pendingBytes = bytes; _pendingName = name; _error = null; });
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); }
  }
  Future<void> _upload() async {
    if (_pendingBytes == null) return;
    final ok = await _send('daily-evidence', {'name': _pendingName, 'base64': base64Encode(_pendingBytes!)});
    if (ok && mounted) setState(() { _pendingBytes = null; _pendingName = null; });
  }
  Future<void> _openEvidence(Map evidence) async {
    final url = Uri.tryParse(evidence['url']?.toString() ?? '');
    if (url == null || url.scheme != 'https') { setState(() => _error = 'Actualiza la tarea para abrir la evidencia.'); return; }
    if (evidence['contentType'].toString().startsWith('image/')) {
      await showDialog<void>(context: context, builder: (c) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [Flexible(child: InteractiveViewer(child: Image.network(url.toString(), errorBuilder: (_, error, stack) => Padding(padding: EdgeInsets.all(24), child: Text('El enlace expiró. Actualiza la tarea.'))))), TextButton(onPressed: () => Navigator.pop(c), child: Text('Cerrar'))])));
    } else if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) { setState(() => _error = 'No se pudo abrir el archivo. Actualiza la tarea e intenta otra vez.'); }
  }
  @override void dispose() { _comment.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    Theme.of(context);
    final editable = _own && _ready && !_busy && _task['status'] != 'completado';
    return Scaffold(appBar: AppBar(title: Text('Tarea y evidencias'), actions: [IconButton(tooltip: 'Actualizar tarea', onPressed: _busy ? null : _load, icon: Icon(Icons.refresh))]),
      body: ListView(padding: EdgeInsets.all(20), children: [
        Text(_task['title'] as String, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        SizedBox(height: 10), Text(_task['details'] as String? ?? ''), SizedBox(height: 10),
        Text('Para ${_task['userName']}\nAsignó ${_task['createdByName']}\nEstado: ${_task['status']}', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.6)),
        if (_busy) Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
        if (_error != null) Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Colors.orangeAccent))),
        SizedBox(height: 18), Text('Evidencias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        for (final evidence in _task['evidence'] as List? ?? []) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.attachment), title: Text(evidence['name'] as String), subtitle: Text('Guardada en la tarea'), trailing: Icon(Icons.open_in_new), onTap: () => _openEvidence(evidence as Map)),
        if (_own && _task['status'] != 'completado') ...[
          SizedBox(height: 10),
          Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: editable ? _pick : null, icon: Icon(Icons.attach_file), label: Text('Adjuntar foto o PDF')), OutlinedButton.icon(onPressed: editable ? () => _pick(camera: true) : null, icon: Icon(Icons.camera_alt_outlined), label: Text('Tomar foto'))]),
          if (_pendingBytes != null) ...[Text('Por subir: $_pendingName'), FilledButton(onPressed: editable ? _upload : null, child: Text('Subir evidencia'))],
          SizedBox(height: 14),
          TextField(controller: _comment, enabled: editable, maxLength: 2000, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'Avance o comentario')),
          OutlinedButton(onPressed: editable ? () async { if (_comment.text.trim().isEmpty) { setState(() => _error = 'Escribe tu avance.'); return; } if (await _send('daily-progress', {'comment': _comment.text.trim()}) && mounted) _comment.clear(); } : null, child: Text('Guardar avance')),
          SizedBox(height: 14),
          FilledButton.icon(onPressed: editable && (_task['evidenceCount'] as num? ?? 0) > 0 ? () => _send('daily-complete') : null, icon: Icon(Icons.task_alt), label: Text('Entregar tarea terminada')),
          if ((_task['evidenceCount'] as num? ?? 0) == 0) Text('Adjunta al menos una evidencia para terminar.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60))),
        ],
        SizedBox(height: 20),
        for (final event in (_task['history'] as List? ?? []).reversed) ListTile(contentPadding: EdgeInsets.zero, title: Text(event['comment']?.toString() ?? ''), subtitle: Text(event['actorName']?.toString() ?? '')),
      ]),
    );
  }
}
