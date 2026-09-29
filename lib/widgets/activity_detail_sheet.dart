import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/actividad_model.dart';
import '../models/evidencia_actividad_model.dart';
import '../presentation/appearance.dart';
import '../services/actividades_service.dart';
import '../services/inventory_photo_codec.dart';
import 'inline_photo.dart';
import 'protected_media_viewer.dart';
import 'work_status.dart';

class ActivityDetailSheet extends StatefulWidget {
  final ActividadModel activity;
  final bool admin;
  const ActivityDetailSheet({super.key, required this.activity, this.admin = false});
  @override State<ActivityDetailSheet> createState() => _ActivityDetailState();
}
class _ActivityDetailState extends State<ActivityDetailSheet> {
  final _service = ActividadesService();
  final _comment = TextEditingController();
  final _files = <ArchivoEvidenciaPendiente>[];
  late final _activityStream = FirebaseFirestore.instance.collection('actividades').doc(widget.activity.id).snapshots();
  late final _evidenceStream = _service.obtenerEvidenciasActividad(widget.activity.id);
  late final _historyStream = _service.obtenerAvancesActividad(widget.activity.id);
  bool _busy = false;
  String? _error;
  String? _operation, _operationPayload;
  @override void dispose() { _comment.dispose(); super.dispose(); }
  Future<void> _pick({bool camera = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (camera) {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
        if (photo == null) return;
        final bytes = await photo.readAsBytes();
        final encoded = InventoryPhotoCodec.decode(await InventoryPhotoCodec.encode(bytes))!;
        if (mounted) setState(() => _files.add(ArchivoEvidenciaPendiente(nombre: photo.name, tipoMime: 'image/png', tamanioBytes: encoded.length, lectorBytes: () async => encoded)));
      } else {
        final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'], allowMultiple: true);
        if (files.isEmpty) return;
        for (final file in files) {
          final length = await file.length();
          if (length > 8 * 1024 * 1024) throw StateError('Elige archivos de menos de 8 MB.');
          final isPdf = file.name.toLowerCase().endsWith('.pdf');
          if (isPdf && length > 500 * 1024) throw StateError('Usa un PDF de hasta 500 KB o adjunta fotos.');
          var bytes = await file.readAsBytes();
          if (!isPdf) bytes = InventoryPhotoCodec.decode(await InventoryPhotoCodec.encode(bytes))!;
          final savedBytes = bytes;
          if (mounted) setState(() => _files.add(ArchivoEvidenciaPendiente(nombre: file.name,
            tipoMime: isPdf ? 'application/pdf' : 'image/png', tamanioBytes: savedBytes.length, lectorBytes: () async => savedBytes)));
        }
      }
    } catch (error) { if (mounted) setState(() => _error = error is StateError ? error.message.toString() : 'No pudimos preparar el archivo. Prueba otra foto.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _save(ActividadModel task, {bool submit = false}) async {
    if (_busy) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final comment = _comment.text.trim();
    if (_files.isEmpty && comment.isEmpty && !(submit && task.totalEvidencias > 0)) {
      setState(() => _error = 'Adjunta una foto o describe lo que hiciste.'); return;
    }
    final payload = '$submit:$comment:${_files.map((e) => '${e.nombre}:${e.tamanioBytes}').join('|')}';
    if (_operationPayload != payload) {
      _operationPayload = payload;
      _operation = '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    }
    setState(() { _busy = true; _error = null; });
    try {
      final notified = await _service.registrarAvance(actividadId: task.id, trabajadorId: uid,
        comentario: comment.isEmpty && submit ? 'Trabajo terminado; evidencias adjuntas.' : comment,
        archivos: List.of(_files), esCierre: submit, operationId: _operation);
      if (!mounted) return;
      setState(() { _files.clear(); _comment.clear(); _operation = null; _operationPayload = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notified
        ? submit ? 'Entrega guardada. Ya se puede aprobar.' : 'Avance y aviso guardados.'
        : 'Trabajo guardado. El aviso no se confirmó; la entrega sigue disponible para revisión.')));
    } catch (error) { if (mounted) setState(() => _error = 'No se confirmó el guardado. Conservamos tu descripción y adjuntos para reintentar. ${error is StateError ? error.message : ''}'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _review(ActividadModel task, bool approve) async {
    if (_busy) return;
    if (!approve && _comment.text.trim().isEmpty) { setState(() => _error = 'Escribe qué debe corregirse.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final notified = await _service.revisarActividad(actividadId: task.id, aprobar: approve,
        comentario: _comment.text, entregaEsperada: task.completadoEn);
      if (mounted) {
        _comment.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notified ? 'Revisión guardada y aviso enviado a la app.' : 'Revisión guardada. El aviso no se confirmó.')));
      }
    } catch (error) { if (mounted) setState(() => _error = error is StateError ? error.message.toString() : 'No se confirmó la revisión. Actualiza e intenta de nuevo.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _open(String url) async {
    if (url.startsWith('data:image/')) {
      await showDialog<void>(context: context, builder: (c) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: InteractiveViewer(child: InlinePhoto(url, fit: BoxFit.contain))),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
      ])));
    } else { await showProtectedMedia(context, url); }
  }
  @override Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Material(
    color: StiloColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .92,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: _activityStream, builder: (context, snapshot) {
        final task = snapshot.hasData && snapshot.data!.exists ? ActividadModel.fromJson(snapshot.data!.data()!, snapshot.data!.id) : widget.activity;
        final own = FirebaseAuth.instance.currentUser?.uid == task.asignadoATrabajadorId;
        final ready = snapshot.hasData && snapshot.data!.exists && !snapshot.hasError;
        final editing = own && !task.porAprobar && !task.aprobada;
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [const Expanded(child: Text('Actividad del proyecto', style: TextStyle(fontWeight: FontWeight.w700))), IconButton(tooltip: 'Cerrar actividad', onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))])),
          Expanded(child: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 100), children: [
            Align(alignment: Alignment.centerLeft, child: WorkStatus(task.estadoVisible)), const SizedBox(height: 14),
            Text(task.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
            Text(task.descripcion, style: const TextStyle(height: 1.5)), const SizedBox(height: 12),
            Text('Entrega: ${DateFormat('dd/MM/yyyy · HH:mm').format(task.fechaTermino)}', style: TextStyle(color: StiloColors.text.withValues(alpha: .65))),
            if (!ready) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(snapshot.hasError ? 'No pudimos consultar la actividad. Comprueba tu conexión.' : 'Conectando con el registro del servidor…')),
            if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            if (task.observacionesAdmin.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Observación de Administración\n${task.observacionesAdmin}'))),
            if (task.porAprobar) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Trabajo entregado. Administración puede aprobarlo o solicitar cambios.')),
            const SizedBox(height: 18), const Text('Fotos y evidencias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            StreamBuilder<List<EvidenciaActividad>>(stream: _evidenceStream, builder: (context, evidence) {
              if (evidence.hasError) return const Text('No pudimos cargar las evidencias.');
              final files = evidence.data ?? [];
              return Column(children: [
                for (final e in files) ListTile(contentPadding: EdgeInsets.zero, leading: e.esImagen ? ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 48, height: 48, child: InlinePhoto(e.url, fit: BoxFit.cover))) : const Icon(Icons.description_outlined), title: Text(e.nombre), trailing: const Icon(Icons.open_in_new), onTap: () => _open(e.url)),
                for (final url in task.evidenciaFotos.where((u) => !files.any((e) => e.url == u))) ListTile(title: const Text('Evidencia anterior'), leading: const Icon(Icons.photo_outlined), onTap: () => _open(url)),
                if (files.isEmpty && task.evidenciaFotos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Todavía no hay adjuntos. También puedes entregar con una descripción.')),
              ]);
            }),
            if (editing) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: _busy || !ready ? null : _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Adjuntar fotos')), OutlinedButton.icon(onPressed: _busy || !ready ? null : () => _pick(camera: true), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Tomar foto'))]),
              for (final file in _files) ListTile(title: Text(file.nombre), subtitle: const Text('Se guardará con tu avance o entrega'), trailing: IconButton(tooltip: 'Quitar adjunto', onPressed: _busy ? null : () => setState(() => _files.remove(file)), icon: const Icon(Icons.close))),
              const SizedBox(height: 12), TextField(controller: _comment, enabled: !_busy && ready, maxLength: 2000, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '¿Qué hiciste?', hintText: 'Describe el avance o el trabajo terminado')),
              OutlinedButton.icon(onPressed: _busy || !ready ? null : () => _save(task), icon: const Icon(Icons.save_outlined), label: const Text('Guardar avance')),
              FilledButton.icon(onPressed: _busy || !ready ? null : () => _save(task, submit: true), icon: const Icon(Icons.task_alt), label: const Text('Marcar como terminada')),
            ],
            if (widget.admin && task.porAprobar) ...[
              const SizedBox(height: 18), const Text('Revisar entrega', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12), TextField(controller: _comment, enabled: !_busy && ready, maxLength: 2000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Observación o cambios necesarios')),
              FilledButton.icon(onPressed: _busy || !ready ? null : () => _review(task, true), icon: const Icon(Icons.verified_outlined), label: const Text('Aprobar y finalizar')),
              OutlinedButton.icon(onPressed: _busy || !ready ? null : () => _review(task, false), icon: const Icon(Icons.edit_note), label: const Text('Solicitar cambios')),
            ],
            if (widget.admin && !task.porAprobar && !editing) ...[
              const SizedBox(height: 16), TextField(controller: _comment, maxLength: 2000, maxLines: 3, decoration: const InputDecoration(labelText: 'Agregar observación')),
              OutlinedButton(onPressed: _busy || !ready ? null : () async {
                setState(() => _busy = true);
                try { await _service.registrarObservacionesAdmin(task.id, _comment.text.trim()); if (mounted) _comment.clear(); }
                catch (_) { if (mounted) setState(() => _error = 'No se guardó la observación.'); }
                finally { if (mounted) setState(() => _busy = false); }
              }, child: const Text('Guardar observación')),
            ],
            const SizedBox(height: 24), const Text('Historial de avances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            StreamBuilder<List<AvanceActividad>>(stream: _historyStream, builder: (context, history) {
              if (history.hasError) return const Text('No se pudo consultar el historial.');
              return Column(children: [for (final entry in history.data ?? <AvanceActividad>[]) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(entry.esCierre ? Icons.task_alt : Icons.history), title: Text(entry.comentario), subtitle: Text('${DateFormat('dd/MM · HH:mm').format(entry.fecha)} · ${entry.cantidadEvidencias} adjuntos'))]);
            }),
          ])),
        ]);
      }),
    )),
  ));
}
