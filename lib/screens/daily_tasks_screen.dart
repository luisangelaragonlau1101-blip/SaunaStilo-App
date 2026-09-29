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
import '../services/inventory_photo_codec.dart';
import '../workflow/staff_policy.dart';
import '../widgets/work_status.dart';
import 'modal_asignar_actividades.dart';

String _operation() => '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class DailyTasksScreen extends StatefulWidget {
  final UserModel user;
  final DateTime? day;
  final bool embedded, operations;
  final String kind;
  final CompanyLearningService? service;
  const DailyTasksScreen({super.key, required this.user, this.day, this.service, this.embedded = false,
    this.kind = 'dia', this.operations = false});
  @override State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}
class _DailyTasksScreenState extends State<DailyTasksScreen> with WidgetsBindingObserver {
  late final CompanyLearningService _service = widget.service ?? CompanyLearningService();
  late DateTime _day = widget.day ?? AttendanceGatewayService.today;
  List<Map<String, dynamic>> _items = [];
  Timer? _timer;
  bool _busy = false;
  String? _error;
  String _filter = 'abiertas';
  String get _key => widget.operations ? DateFormat('yyyyMM').format(_day) : AttendanceGatewayService.dayKey(_day);
  String get _title => widget.operations ? 'Instalaciones y envíos' : widget.kind == 'extra' ? 'Tareas extras' : 'Tareas del día';
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && TickerMode.of(context) && WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused && WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden) unawaited(_load());
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) unawaited(_load()); }
  Future<void> _load() async {
    if (_busy) return;
    final key = _key;
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _service.call('daily-list', {'day': key});
      if (mounted && key == _key) setState(() => _items = (response['items'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList());
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); }
    finally { if (mounted) { setState(() => _busy = false); if (key != _key) unawaited(_load()); } }
  }
  Future<void> _create() async {
    if (!canAssignWork(widget.user.rol)) return;
    await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ModalAsignarActividad(proyectoId: '', rolUsuario: widget.user.rol, initialDay: _day,
        workKind: widget.operations ? 'instalacion' : widget.kind, operations: widget.operations));
    if (mounted) await _load();
  }
  @override void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override Widget build(BuildContext context) {
    final all = _items.where((t) => widget.operations || (t['workKind'] ?? 'dia') == widget.kind).toList();
    final pending = all.where((t) => t['status'] != 'completado').length;
    final review = all.where((t) => t['status'] == 'en_revision').length;
    final items = all.where((t) => switch (_filter) { 'revision' => t['status'] == 'en_revision', 'finalizadas' => t['status'] == 'completado', 'abiertas' => t['status'] != 'completado', _ => true }).toList();
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(_title)),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26), color: StiloColors.surface,
          border: Border.all(color: StiloColors.border),
          boxShadow: [BoxShadow(color: const Color(0xFF8E1538).withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 8))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(widget.operations ? 'Cada entrega, de principio a fin. Comparte fotos, avances y el porcentaje real.' : widget.kind == 'extra' ? 'Asignaciones independientes de los proyectos, con su propia entrega y aprobación.' : 'Tu trabajo de hoy, con el siguiente paso siempre a la vista.', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.5)),
            const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('$pending abiertas')), Chip(label: Text('$review por aprobar')), Chip(label: Text('${all.length - pending} finalizadas'))]),
          ])),
        const SizedBox(height: 12),
        Row(children: [IconButton(tooltip: widget.operations ? 'Mes anterior' : 'Día anterior', onPressed: _busy ? null : () { setState(() => _day = widget.operations ? DateTime(_day.year, _day.month - 1) : _day.subtract(const Duration(days: 1))); _load(); }, icon: const Icon(Icons.chevron_left)),
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () async {
            final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime(2035));
            if (picked != null && mounted) { setState(() { _day = picked; _items = []; }); await _load(); }
          }, icon: const Icon(Icons.calendar_month), label: Text(DateFormat(widget.operations ? 'MM/yyyy' : 'dd/MM/yyyy').format(_day)))),
          IconButton(tooltip: widget.operations ? 'Mes siguiente' : 'Día siguiente', onPressed: _busy ? null : () { setState(() => _day = widget.operations ? DateTime(_day.year, _day.month + 1) : _day.add(const Duration(days: 1))); _load(); }, icon: const Icon(Icons.chevron_right)),
        ]),
        if (widget.operations) const Padding(padding: EdgeInsets.all(8), child: Text('Historial por mes de asignación. Los avances y revisiones permanecen en su mes original.')),
        if (canAssignWork(widget.user.rol)) FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_task), label: Text(widget.operations ? 'Asignar instalación o envío' : 'Asignar tarea')),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [for (final entry in {'abiertas':'Abiertas', 'revision':'Por aprobar', 'finalizadas':'Finalizadas', 'todas':'Todas'}.entries)
          ChoiceChip(label: Text(entry.value), selected: _filter == entry.key, onSelected: (_) => setState(() => _filter = entry.key))]),
        if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), TextButton.icon(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh), label: const Text('Volver a intentar'))]))),
        if (!_busy && _error == null && items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Todo despejado en esta vista. Puedes cambiar de fecha o filtro.')),
        for (final task in items) WorkTaskCard(task: task, onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DailyTaskDetail(user: widget.user, task: task, service: _service)));
          if (mounted) await _load();
        }),
      ])),
    );
  }
}

class WorkTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  const WorkTaskCard({super.key, required this.task, required this.onTap});
  @override Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(workKindLabel(task['workKind']), style: TextStyle(fontSize: 12, color: StiloColors.text.withValues(alpha: .6)))), WorkStatus(task['status'])]),
      const SizedBox(height: 12), Text(task['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6), Text('${task['userName']} · ${task['evidenceCount'] ?? 0} adjuntos', style: TextStyle(color: StiloColors.text.withValues(alpha: .7))),
      const SizedBox(height: 14), Row(children: [Expanded(child: LinearProgressIndicator(value: (((task['percentage'] as num?) ?? 0).clamp(0, 100).toDouble() / 100), minHeight: 5, borderRadius: BorderRadius.circular(6))), const SizedBox(width: 12), Text('${task['percentage'] ?? 0} %'), const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 18)]),
    ]))));
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
  String? _error, _pendingName, _noticeWarning, _retryAction;
  Map<String, dynamic>? _retryData;
  Uint8List? _pendingBytes;
  double _percentage = 0;
  bool get _own => widget.user.id == _task['userId'];
  bool get _reviewer => widget.user.rol == 'admin' || widget.user.rol == 'maestro' && widget.user.id == _task['createdBy'];
  bool get _operational => ['instalacion', 'envio'].contains(_task['workKind']);
  bool get _closed => ['completado', 'en_revision'].contains(_task['status']);
  Map<String, dynamic> get _reference => {'day': _task['day'], 'taskId': _task['taskId']};
  @override void initState() { super.initState(); unawaited(_load()); }
  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _service.call('daily-read', _reference);
      if (mounted) setState(() { _task = Map<String, dynamic>.from(response['task'] as Map); _percentage = (_task['percentage'] as num? ?? 0).toDouble(); _ready = true; });
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
      setState(() {
        _task = Map<String, dynamic>.from(response['task'] as Map);
        _percentage = (_task['percentage'] as num? ?? 0).toDouble();
        _noticeWarning = response['notificationWarning'] as String?;
        _retryAction = _noticeWarning == null ? null : action;
        _retryData = _noticeWarning == null ? null : {...data};
      });
      if (_noticeWarning == null) _operations.remove(operationKey);
      return true;
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); return false; }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _pick({bool camera = false}) async {
    if (_busy) return;
    try {
      Uint8List bytes; String name;
      if (camera) {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
        if (photo == null) return;
        bytes = await photo.readAsBytes(); name = photo.name;
      } else {
        final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'], allowMultiple: false);
        if (files.isEmpty) return;
        final file = files.single;
        if (await file.length() > 8 * 1024 * 1024) throw StateError('El archivo debe pesar como máximo 8 MB.');
        bytes = await file.readAsBytes(); name = file.name;
      }
      if (!name.toLowerCase().endsWith('.pdf')) {
        bytes = InventoryPhotoCodec.decode(await InventoryPhotoCodec.encode(bytes))!;
        name = '${name.split('.').first}.png';
      }
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) throw StateError('El PDF debe pesar como máximo 2 MB.');
      if (mounted) setState(() { _pendingBytes = bytes; _pendingName = name; _error = null; });
    } catch (error) { if (mounted) setState(() => _error = CompanyLearningService.message(error)); }
  }
  Future<bool> _upload() async {
    if (_pendingBytes == null) return true;
    final ok = await _send('daily-evidence', {'name': _pendingName, 'base64': base64Encode(_pendingBytes!)});
    if (ok && mounted) setState(() { _pendingBytes = null; _pendingName = null; });
    return ok;
  }
  Future<void> _deliver() async {
    if (_busy || !_ready) return;
    if (_pendingBytes == null && (_task['evidenceCount'] as num? ?? 0) == 0 && _comment.text.trim().length < 5) {
      setState(() => _error = 'Adjunta una foto o escribe qué terminaste.'); return;
    }
    if (!await _upload() || !mounted) return;
    if (await _send('daily-complete', {'comment': _comment.text.trim()}) && mounted) _comment.clear();
  }
  Future<void> _review(bool approve) async {
    if (!approve && _comment.text.trim().isEmpty) { setState(() => _error = 'Explica qué debe corregirse.'); return; }
    if (await _send('daily-review', {'decision': approve ? 'approve' : 'changes', 'submissionId': _task['submissionId'], 'comment': _comment.text.trim()}) && mounted) _comment.clear();
  }
  Future<void> _openEvidence(Map evidence) async {
    final url = Uri.tryParse(evidence['url']?.toString() ?? '');
    if (url == null || url.scheme != 'https') { setState(() => _error = 'Actualiza la tarea para abrir la evidencia.'); return; }
    if (evidence['contentType'].toString().startsWith('image/')) {
      await showDialog<void>(context: context, builder: (c) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [Flexible(child: InteractiveViewer(child: Image.network(url.toString(), errorBuilder: (_, error, stack) => const Padding(padding: EdgeInsets.all(24), child: Text('El enlace expiró. Actualiza la tarea.'))))), TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))])));
    } else if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) { setState(() => _error = 'No se pudo abrir el archivo. Actualiza la tarea e intenta otra vez.'); }
  }
  @override void dispose() { _comment.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final enabled = _ready && !_busy;
    final editable = enabled && !_closed && (_own || _operational && widget.user.rol == 'admin');
    final review = _reviewer && _task['status'] == 'en_revision';
    return Scaffold(appBar: AppBar(title: Text(workKindLabel(_task['workKind'])), actions: [IconButton(tooltip: 'Actualizar tarea', onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 110), children: [
        Align(alignment: Alignment.centerLeft, child: WorkStatus(_task['status'])), const SizedBox(height: 16),
        Text(_task['title'] as String, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10), Text(_task['details'] as String? ?? '', style: const TextStyle(height: 1.5)),
        const SizedBox(height: 12), Text('Responsable: ${_task['userName']}\nAsignó: ${_task['createdByName']}', style: TextStyle(color: StiloColors.text.withValues(alpha: .70), height: 1.6)),
        const SizedBox(height: 14), LinearProgressIndicator(value: (((_task['percentage'] as num?) ?? 0).clamp(0, 100).toDouble() / 100), minHeight: 7, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 7), Text('${_task['percentage'] ?? 0} % de avance'),
        if (_task['status'] == 'en_revision') const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Trabajo entregado. Falta la aprobación para finalizar.')),
        if ((_task['reviewComment'] ?? '').toString().isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Revisión: ${_task['reviewComment']}'))),
        if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_noticeWarning != null) Card(child: Column(children: [Padding(padding: const EdgeInsets.all(12), child: Text(_noticeWarning!)), TextButton(onPressed: !enabled || _retryAction == null ? null : () => _send(_retryAction!, _retryData!), child: const Text('Reintentar aviso'))])),
        const SizedBox(height: 18), const Text('Evidencias y fotos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        for (final evidence in _task['evidence'] as List? ?? []) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.attachment), title: Text(evidence['name'] as String), subtitle: const Text('Guardada en la tarea'), trailing: const Icon(Icons.open_in_new), onTap: () => _openEvidence(evidence as Map)),
        if (!_closed && (_own || _operational && widget.user.rol == 'admin')) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: editable ? _pick : null, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Adjuntar foto o PDF')), OutlinedButton.icon(onPressed: editable ? () => _pick(camera: true) : null, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Tomar foto'))]),
          if (_pendingBytes != null) ListTile(title: Text(_pendingName!), subtitle: const Text('Se subirá al guardar o entregar'), trailing: IconButton(tooltip: 'Quitar adjunto', onPressed: _busy ? null : () => setState(() { _pendingBytes = null; _pendingName = null; }), icon: const Icon(Icons.close))),
          const SizedBox(height: 14),
          TextField(controller: _comment, enabled: editable, maxLength: 2000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '¿Qué hiciste?', hintText: 'Describe tu avance o el trabajo terminado')),
          Text('Avance: ${_percentage.round()} %'), Slider(value: _percentage.clamp(0, 100).toDouble(), min: 0, max: 100, divisions: 20, label: '${_percentage.round()} %', onChanged: editable ? (v) => setState(() => _percentage = v) : null),
          OutlinedButton.icon(onPressed: editable ? () async {
            final comment = _comment.text.trim(); final percentage = _percentage.round();
            if (comment.isEmpty) { setState(() => _error = 'Describe tu avance para guardarlo.'); return; }
            if (!await _upload() || !mounted) return;
            if (await _send('daily-progress', {'comment': comment, 'percentage': percentage}) && mounted) _comment.clear();
          } : null, icon: const Icon(Icons.save_outlined), label: const Text('Guardar avance')),
          if (_own) FilledButton.icon(onPressed: editable ? _deliver : null, icon: const Icon(Icons.task_alt), label: const Text('Marcar como terminada')),
          const Text('Entrega con una foto, un archivo o una descripción. Después se revisa y aprueba.', style: TextStyle(fontSize: 12)),
        ],
        if (review) ...[
          const SizedBox(height: 18), const Text('Revisar entrega', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12), TextField(controller: _comment, enabled: enabled, maxLength: 2000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Observación de la revisión')),
          FilledButton.icon(onPressed: enabled ? () => _review(true) : null, icon: const Icon(Icons.verified_outlined), label: const Text('Aprobar y finalizar')),
          OutlinedButton.icon(onPressed: enabled ? () => _review(false) : null, icon: const Icon(Icons.edit_note), label: const Text('Solicitar cambios')),
        ],
        const SizedBox(height: 24), const Text('Historial de avances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        for (final event in (_task['history'] as List? ?? []).reversed) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history_rounded), title: Text('${event['comment'] ?? ''}${event['percentage'] != null ? ' · ${event['percentage']} %' : ''}'), subtitle: Text('${event['actorName'] ?? ''}\n${event['at'] ?? ''}')),
      ]),
    );
  }
}
