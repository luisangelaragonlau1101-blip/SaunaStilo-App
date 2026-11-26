import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../services/company_learning_service.dart';
import '../services/inventory_photo_codec.dart';
import '../workflow/task_lifecycle.dart';

class TaskPhoto {
  final Uint8List bytes;
  final String name;
  const TaskPhoto({required this.bytes, required this.name});
}

typedef TaskPhotoCapture = Future<TaskPhoto?> Function();

String taskOperationId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

/// The same controls work on Home, daily work and project activity cards.
/// Every mutation still goes through the authenticated task service.
class QuickTaskActions extends StatefulWidget {
  final Map<String, dynamic> task;
  final UserModel user;
  final CompanyLearningService service;
  final Future<void> Function() onChanged;
  final VoidCallback onDetails;
  final TaskPhotoCapture? capturePhoto;
  const QuickTaskActions({
    super.key,
    required this.task,
    required this.user,
    required this.service,
    required this.onChanged,
    required this.onDetails,
    this.capturePhoto,
  });
  @override
  State<QuickTaskActions> createState() => _QuickTaskActionsState();
}

class _QuickTaskActionsState extends State<QuickTaskActions> {
  bool _busy = false, _loadingReview = false;
  String? _error;
  Map<String, dynamic>? _review;
  final _operations = <String, String>{};
  bool get _admin => widget.user.rol == 'admin';
  bool get _own => taskAssignedTo(widget.task, widget.user.id);
  String get _status => (widget.task['status'] ?? 'pendiente').toString();
  bool get _order =>
      (widget.task['installationOrderId'] ?? '').toString().isNotEmpty;
  @override
  void initState() {
    super.initState();
    if (_admin && _status == 'en_revision' && !_order) _loadReview();
  }

  @override
  void didUpdateWidget(covariant QuickTaskActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.task['taskId'] != widget.task['taskId'] ||
        oldWidget.task['submittedAt'] != widget.task['submittedAt'] ||
        oldWidget.task['status'] != widget.task['status']) {
      _review = null;
      _error = null;
      if (_admin && _status == 'en_revision' && !_order) _loadReview();
    }
  }

  Future<void> _loadReview() async {
    if (_loadingReview) return;
    final id = widget.task['taskId'], uid = widget.user.id;
    setState(() {
      _loadingReview = true;
      _error = null;
    });
    try {
      final response = await widget.service.call('daily-read', {'taskId': id});
      if (mounted && widget.task['taskId'] == id && widget.user.id == uid) {
        setState(
          () => _review = Map<String, dynamic>.from(response['task'] as Map),
        );
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = CompanyLearningService.message(error));
    } finally {
      if (mounted) setState(() => _loadingReview = false);
    }
  }

  Future<void> _run(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (_busy) return;
    final key = '$action:${jsonEncode(body)}';
    final id = _operations.putIfAbsent(key, taskOperationId);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.service.call(action, {
        'taskId': widget.task['taskId'],
        ...body,
        'operationId': id,
      });
      if (result['saved'] != true)
        throw StateError('No se confirmó el guardado.');
      if (!mounted) return;
      await widget.onChanged();
      if (mounted && result['notificationWarning'] is String) {
        setState(() => _error = result['notificationWarning'] as String);
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = CompanyLearningService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deliver() async {
    final delivered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickTaskDeliverySheet(
        task: widget.task,
        service: widget.service,
        capturePhoto: widget.capturePhoto,
      ),
    );
    if (delivered == true && mounted) await widget.onChanged();
  }

  Future<void> _reviewDecision(bool approve) async {
    if (_review == null || _loadingReview) return;
    String comment = '';
    if (!approve) {
      final controller = TextEditingController();
      final route = DialogRoute<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Qué debe corregirse?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Una indicación breve y clara',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty)
                  Navigator.pop(c, controller.text.trim());
              },
              child: const Text('Enviar corrección'),
            ),
          ],
        ),
      );
      final answer = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      await route.completed;
      controller.dispose();
      if (answer == null || !mounted) return;
      comment = answer;
    }
    await _run('daily-review', {
      'decision': approve ? 'approve' : 'changes',
      'comment': comment,
      'submissionId': _review!['submissionId'],
      'submittedAt': _review!['submittedAt'],
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_order) {
      return FilledButton.icon(
        onPressed: widget.onDetails,
        icon: const Icon(Icons.checklist_rounded),
        label: const Text('ABRIR CHECKLIST'),
      );
    }
    if (!_admin && !_own) return const SizedBox.shrink();
    final actions = <Widget>[];
    if (_status == 'en_revision' && _admin) {
      actions.addAll([
        FilledButton.icon(
          onPressed: _busy || _review == null
              ? null
              : () => _reviewDecision(true),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('APROBAR'),
        ),
        OutlinedButton.icon(
          onPressed: _busy || _review == null
              ? null
              : () => _reviewDecision(false),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Solicitar corrección'),
        ),
      ]);
    } else if (!['completado', 'en_revision'].contains(_status)) {
      if (_status == 'pendiente') {
        actions.add(
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run('daily-start'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('INICIAR'),
          ),
        );
      }
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _deliver,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('TERMINAR'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_status == 'en_revision' && _admin) ...[
          if (_loadingReview) const LinearProgressIndicator(),
          if (_review != null)
            TaskEvidencePreview(
              evidence: _review!['evidence'] as List? ?? const [],
            ),
          if (_review == null && !_loadingReview)
            TextButton.icon(
              onPressed: _loadReview,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Cargar evidencia para revisar'),
            ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        ...actions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(width: double.infinity, child: action),
          ),
        ),
        if (_status == 'en_revision' && !_admin)
          const Text(
            'Entregada · pendiente de revisión',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class TaskEvidencePreview extends StatelessWidget {
  final List evidence;
  const TaskEvidencePreview({super.key, required this.evidence});
  Widget _image(Map item, {BoxFit fit = BoxFit.cover}) {
    final url = (item['url'] ?? '').toString();
    Widget fallback() =>
        const Center(child: Icon(Icons.insert_drive_file_outlined, size: 30));
    try {
      if (url.startsWith('data:image/')) {
        return Image.memory(
          base64Decode(url.substring(url.indexOf(',') + 1)),
          fit: fit,
          errorBuilder: (_, error, stack) => fallback(),
        );
      }
      if (Uri.tryParse(url)?.scheme == 'https' &&
          (item['contentType'] ?? '').toString().startsWith('image/')) {
        return Image.network(
          url,
          fit: fit,
          errorBuilder: (_, error, stack) => fallback(),
        );
      }
    } catch (_) {
      /* Invalid historical attachments retain their detail link. */
    }
    return fallback();
  }

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty)
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Sin archivos adjuntos en esta entrega.'),
      );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in evidence.take(3))
            if (value is Map)
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: InteractiveViewer(
                            child: _image(value, fit: BoxFit.contain),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  ),
                ),
                child: Tooltip(
                  message: (value['name'] ?? 'Evidencia').toString(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: _image(value),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class QuickTaskDeliverySheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final CompanyLearningService service;
  final TaskPhotoCapture? capturePhoto;
  const QuickTaskDeliverySheet({
    super.key,
    required this.task,
    required this.service,
    this.capturePhoto,
  });
  @override
  State<QuickTaskDeliverySheet> createState() => _QuickTaskDeliverySheetState();
}

class _QuickTaskDeliverySheetState extends State<QuickTaskDeliverySheet> {
  late Map<String, dynamic> _task = {...widget.task};
  final _comment = TextEditingController();
  final _uploadOperation = taskOperationId(),
      _completeOperation = taskOperationId();
  TaskPhoto? _photo;
  String? _error;
  bool _loading = true, _busy = false, _uploaded = false, _capturing = false;
  bool get _required => _task['requiresEvidence'] == true;
  bool get _hasEvidence =>
      (_task['evidenceCount'] as num? ?? 0) > 0 ||
      (_task['evidence'] as List? ?? const []).isNotEmpty;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    try {
      final result = await widget.service.call('daily-read', {
        'taskId': _task['taskId'],
      });
      if (!mounted) return;
      setState(() {
        _task = Map<String, dynamic>.from(result['task'] as Map);
        _loading = false;
      });
      if (['en_revision', 'completado'].contains(_task['status'])) {
        setState(
          () => _error =
              'La actividad ya fue entregada. Cierra y actualiza la lista.',
        );
        return;
      }
      await _takePhoto();
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = CompanyLearningService.message(error);
        });
    }
  }

  Future<void> _takePhoto({bool gallery = false}) async {
    if (_busy || _capturing) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      TaskPhoto? photo;
      if (widget.capturePhoto != null && !gallery) {
        photo = await widget.capturePhoto!();
      } else {
        final picked = await ImagePicker().pickImage(
          source: gallery ? ImageSource.gallery : ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 75,
        );
        if (picked != null)
          photo = TaskPhoto(
            bytes: await picked.readAsBytes(),
            name: picked.name,
          );
      }
      if (photo == null || !mounted) return;
      final encoded = await InventoryPhotoCodec.encode(photo.bytes);
      if (mounted)
        setState(() {
          _photo = TaskPhoto(
            bytes: InventoryPhotoCodec.decode(encoded)!,
            name: 'trabajo-terminado.png',
          );
          _uploaded = false;
        });
    } catch (error) {
      if (mounted)
        setState(
          () => _error =
              'No se pudo abrir la cámara. Puedes elegir una foto o reintentar.',
        );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _deliver() async {
    if (_loading || _busy || _capturing) return;
    if (_required && !_hasEvidence && _photo == null) {
      setState(
        () => _error = 'Esta actividad necesita una foto antes de entregar.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_photo != null && !_uploaded) {
        final result = await widget.service.call('daily-evidence', {
          'taskId': _task['taskId'],
          'name': _photo!.name,
          'base64': base64Encode(_photo!.bytes),
          'operationId': _uploadOperation,
        });
        if (result['saved'] != true)
          throw StateError('No se confirmó la foto. Reintenta sin cerrar.');
        _uploaded = true;
      }
      final result = await widget.service.call('daily-complete', {
        'taskId': _task['taskId'],
        'comment': _comment.text.trim(),
        'operationId': _completeOperation,
      });
      if (result['saved'] != true)
        throw StateError('No se confirmó la entrega. Reintenta sin cerrar.');
      if (!mounted) return;
      final warning = result['notificationWarning'];
      if (warning is String)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning)));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(() => _error = CompanyLearningService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Entrega tu actividad',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text((_task['title'] ?? 'Actividad').toString()),
          const SizedBox(height: 8),
          const Text(
            'Toma una foto y pulsa Entregar. Administración la revisará.',
          ),
          if (_loading || _busy || _capturing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(),
            ),
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.memory(
                  _photo!.bytes,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (!_loading) ...[
            FilledButton.tonalIcon(
              onPressed: _busy || _capturing || _uploaded ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(
                _photo == null ? 'TOMAR FOTO' : 'Volver a tomar foto',
              ),
            ),
            TextButton.icon(
              onPressed: _busy || _capturing || _uploaded
                  ? null
                  : () => _takePhoto(gallery: true),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir una foto'),
            ),
            if (_required && !_hasEvidence)
              const Text('La foto es obligatoria para esta actividad.'),
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              enabled: !_busy,
              maxLength: 2000,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentario opcional',
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _loading ||
                    _busy ||
                    _capturing ||
                    ['en_revision', 'completado'].contains(_task['status'])
                ? null
                : _deliver,
            icon: const Icon(Icons.send_rounded),
            label: Text(_busy ? 'Entregando…' : 'ENTREGAR'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Seguir trabajando'),
          ),
        ],
      ),
    ),
  );
}
