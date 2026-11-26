import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/evidencia_actividad_model.dart';
import '../models/actividad_model.dart';
import 'actividades_service.dart';
import '../workflow/task_lifecycle.dart';

/// Firestore fallback for the daily-work hub.
///
/// The first version of the hub used the AppDeploy service for daily tasks.
/// That service can be paused independently of Firebase. Project activities
/// already use Firestore, so this adapter keeps the same response shape as the
/// hub while saving the work in the app's existing activity collections.
class FirestoreDailyTasksService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final _names = <String, String>{};
  late final ActividadesService activities = ActividadesService(
    firestore: db,
    auth: auth,
  );

  FirestoreDailyTasksService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = firebaseAuth ?? FirebaseAuth.instance;

  String get _uid {
    final value = auth.currentUser?.uid;
    if (value == null || value.isEmpty) {
      throw StateError('Inicia sesión en Sauna Stilo.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _profile(String uid) async {
    final snapshot = await db.collection('usuarios').doc(uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    if (!snapshot.exists || data['activo'] == false) {
      throw StateError('Tu cuenta no está activa.');
    }
    _names[uid] = (data['nombre'] ?? data['Nombre'] ?? 'Integrante').toString();
    return {
      'id': uid,
      'nombre': (data['nombre'] ?? data['Nombre'] ?? 'Integrante').toString(),
      'rol': (data['rol'] ?? 'trabajador').toString(),
    };
  }

  String _dayKey(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);
    date ??= DateTime.now();
    final local = date.toUtc().subtract(const Duration(hours: 6));
    return '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDay(String value) {
    if (!RegExp(r'^20\d{6}$').hasMatch(value)) {
      throw StateError('Selecciona una fecha válida.');
    }
    final parsed = DateTime.tryParse(
      '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6)}',
    );
    if (parsed == null ||
        '${parsed.year.toString().padLeft(4, '0')}${parsed.month.toString().padLeft(2, '0')}${parsed.day.toString().padLeft(2, '0')}' !=
            value)
      throw StateError('Selecciona una fecha válida.');
    return DateTime.utc(parsed.year, parsed.month, parsed.day, 6);
  }

  String _status(Map<String, dynamic> data) =>
      taskStatus(data['estatus'], approved: data['aprobadoEn'] != null);

  String? _timestampIso(dynamic value) {
    final date = value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : value is String
        ? DateTime.tryParse(value)
        : null;
    return date?.toUtc().toIso8601String();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _visibleDocs(
    Map<String, dynamic> profile, {
    String? projectId,
  }) async {
    final role = profile['rol'];
    final collection = db.collection('actividades');
    if (projectId != null && projectId.isNotEmpty)
      return (await collection.where('proyectoId', isEqualTo: projectId).get())
          .docs;
    if (role == 'admin') return (await collection.get()).docs;
    // This predicate is also the ownership predicate in Firestore rules, so
    // the query remains readable for regular team profiles.
    final uid = _uid;
    final snapshots = await Future.wait([
      collection.where('asignadoATrabajadorId', isEqualTo: uid).get(),
      collection.where('asignadosIds', arrayContains: uid).get(),
    ]);
    return {
      for (final result in snapshots)
        for (final doc in result.docs) doc.id: doc,
    }.values.toList();
  }

  bool _matches(
    Map<String, dynamic> data,
    String requestedDay, {
    bool carryPending = false,
  }) => taskFallsOnDay(
    _dayKey(data['fechaAsignada'] ?? data['fechaInicio']),
    _dayKey(
      data['fechaTermino'] ?? data['fechaAsignada'] ?? data['fechaInicio'],
    ),
    requestedDay,
    carryPending: carryPending,
    approved: _status(data) == 'completado',
  );

  Future<String> _displayName(String id) async {
    if (id.isEmpty) return 'Sin responsable';
    if (_names.containsKey(id)) return _names[id]!;
    final snapshot = await db.collection('usuarios').doc(id).get();
    final data = snapshot.data();
    return _names[id] = (data?['nombre'] ?? data?['Nombre'] ?? 'Integrante')
        .toString();
  }

  Future<List<EvidenciaActividad>> _evidence(String id) async {
    final snapshot = await db
        .collection('actividades')
        .doc(id)
        .collection('evidencias')
        .get();
    final list = snapshot.docs.map(EvidenciaActividad.fromDocument).toList();
    list.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
    return list;
  }

  Future<List<AvanceActividad>> _progress(String id) async {
    final snapshot = await db
        .collection('actividades')
        .doc(id)
        .collection('avances')
        .get();
    final list = snapshot.docs.map(AvanceActividad.fromDocument).toList();
    list.sort((a, b) => b.fecha.compareTo(a.fecha));
    return list;
  }

  Future<Map<String, dynamic>> _task(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool detail = false,
    bool overview = false,
  }) async {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final status = _status(data);
    final evidence = detail
        ? await _evidence(snapshot.id)
        : const <EvidenciaActividad>[];
    // Overview cards do not need to download closed tasks' entire histories.
    // Their detail still reads all events and evidence when opened.
    final progress =
        detail ||
            overview &&
                !['en_revision', 'completado'].contains(status) &&
                data['porcentaje'] is! num
        ? await _progress(snapshot.id)
        : const <AvanceActividad>[];
    var percentage = (data['porcentaje'] is num)
        ? (data['porcentaje'] as num).toInt().clamp(0, 100).toInt()
        : 0;
    for (final item in progress) {
      if (item.porcentaje != null) {
        percentage = item.porcentaje!.clamp(0, 100).toInt();
        break;
      }
    }
    if (status == 'en_revision' || status == 'completado') percentage = 100;
    final assignedId = (data['asignadoATrabajadorId'] ?? '').toString();
    final assignedName =
        _names[assignedId] ??
        (detail || overview
            ? await _displayName(assignedId)
            : (data['asignadoNombre'] ?? 'Integrante').toString());
    final creatorId = (data['creadoPor'] ?? '').toString();
    final creatorName = creatorId.isEmpty || !detail && !overview
        ? 'Administración'
        : await _displayName(creatorId);
    AvanceActividad? submission;
    for (final item in progress) {
      if (item.esCierre) {
        submission = item;
        break;
      }
    }
    final oldPhotos = data['evidenciaFotos'] is List
        ? (data['evidenciaFotos'] as List).whereType<String>().toList()
        : <String>[];
    final evidenceItems = <Map<String, dynamic>>[
      for (final item in evidence)
        {
          'id': item.id,
          'url': item.url,
          'name': item.nombre,
          'contentType': item.tipoMime,
          'size': item.tamanioBytes,
          'storagePath': item.storagePath,
          'createdAt': item.creadoEn.toIso8601String(),
        },
      if (detail)
        for (var i = 0; i < oldPhotos.length; i++)
          if (!evidence.any((e) => e.url == oldPhotos[i]))
            {
              'id': 'legacy_$i',
              'url': oldPhotos[i],
              'name': 'Evidencia anterior ${i + 1}',
              'contentType': 'image/jpeg',
            },
    ];
    int counter(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    final count = math.max(
      math.max(
        counter(data['evidenciasCount']),
        counter(data['cantidadEvidencias']),
      ),
      math.max(oldPhotos.length, evidenceItems.length),
    );
    return {
      'taskId': snapshot.id,
      'day': _dayKey(data['fechaAsignada'] ?? data['fechaInicio']),
      'title': (data['titulo'] ?? 'Tarea').toString(),
      'details': (data['descripcion'] ?? '').toString(),
      'workKind': (data['workKind'] ?? 'dia').toString(),
      'userId': data['asignadoATrabajadorId'] ?? '',
      'userIds': taskResponsibleIds(data),
      'userName': assignedName,
      'createdBy': creatorId,
      'createdByName': creatorName,
      'dueDay': _dayKey(data['fechaTermino'] ?? data['fechaAsignada']),
      'assignedAt': _timestampIso(data['fechaAsignada'] ?? data['fechaInicio']),
      'dueAt': _timestampIso(
        data['fechaTermino'] ?? data['fechaAsignada'] ?? data['fechaInicio'],
      ),
      'approvedAt': _timestampIso(data['aprobadoEn']),
      'projectId': (data['proyectoId'] ?? '').toString(),
      'projectTitle': (data['proyectoTitulo'] ?? data['projectTitle'] ?? '')
          .toString(),
      'installationOrderId': (data['installationOrderId'] ?? '').toString(),
      'requiresEvidence': data['requiereEvidencia'] == true,
      'status': status,
      'percentage': percentage,
      'percentagePendingDetail':
          !detail &&
          !overview &&
          data['porcentaje'] is! num &&
          !['en_revision', 'completado'].contains(status),
      'evidenceCount': count,
      'evidence': evidenceItems,
      'submissionId': submission?.id,
      'submittedAt':
          submission?.fecha.toIso8601String() ??
          _timestampIso(data['completadoEn']),
      'reviewComment': (data['observacionesAdmin'] ?? '').toString(),
      'history': progress
          .map(
            (item) => {
              'id': item.id,
              'kind': item.esCierre ? 'submitted' : 'progress',
              'comment': item.comentario,
              'at': item.fecha.toIso8601String(),
              'actorName': item.trabajadorId == assignedId
                  ? assignedName
                  : 'Administración',
              'percentage': item.porcentaje,
            },
          )
          .toList(),
    };
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getTask(String id) async {
    if (id.trim().isEmpty) throw StateError('Tarea inválida.');
    final snapshot = await db.collection('actividades').doc(id).get();
    if (!snapshot.exists) throw StateError('La tarea ya no existe.');
    return snapshot;
  }

  Future<Map<String, dynamic>> _create(Map<String, dynamic> body) async {
    final uid = _uid;
    final profile = await _profile(uid);
    if (profile['rol'] != 'admin') {
      throw StateError(
        'Solo Administración asigna tareas independientes de proyectos.',
      );
    }
    final title = (body['title'] ?? '').toString().trim();
    final targetIds = taskResponsibleIds(body);
    if (targetIds.isEmpty || targetIds.length > 30) {
      throw StateError('Selecciona de una a treinta personas activas.');
    }
    final targets = await Future.wait(targetIds.map(_profile));
    final day = _parseDay((body['day'] ?? '').toString());
    final due =
        DateTime.tryParse((body['dueAt'] ?? '').toString()) ??
        DateTime.utc(day.year, day.month, day.day, 25);
    final kind = (body['workKind'] ?? 'dia').toString();
    if (![
      'dia',
      'extra',
      'instalacion',
      'envio',
      'mantenimiento',
      'preparacion',
    ].contains(kind)) {
      throw StateError('Tipo de tarea inválido.');
    }
    final operation =
        (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch)
            .toString();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,140}$').hasMatch(operation)) {
      throw StateError('Identificador de tarea inválido.');
    }
    final docId = 'daily_${uid}_$operation';
    await activities.crearActividad(
      ActividadModel(
        id: docId,
        proyectoId: '',
        titulo: title,
        descripcion: (body['details'] ?? '').toString().trim(),
        asignadoATrabajadorId: targetIds.first,
        asignadosIds: targetIds.length > 1 ? targetIds : const [],
        workKind: kind,
        fechaInicio: day,
        fechaAsignada: day,
        fechaTermino: due,
        requiereEvidencia: body['requiresEvidence'] != false,
      ),
    );
    return {
      'saved': true,
      'task': await _task(await _getTask(docId)),
      'target': targets.map((p) => p['nombre']).join(', '),
    };
  }

  Future<Map<String, dynamic>> _writeEvidence(
    DocumentSnapshot<Map<String, dynamic>> task,
    Map<String, dynamic> body,
  ) async {
    final base64 = (body['base64'] ?? '').toString();
    final name = (body['name'] ?? 'evidencia').toString();
    if (base64.isEmpty) throw StateError('Adjunta una foto o un archivo.');
    final bytes = Uint8List.fromList(base64Decode(base64));
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw StateError('El archivo debe pesar como máximo 8 MB.');
    }
    final lower = name.toLowerCase();
    final mime = lower.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
    final notified = await activities.registrarAvance(
      actividadId: task.id,
      trabajadorId: _uid,
      comentario: '',
      archivos: [
        ArchivoEvidenciaPendiente(
          nombre: name,
          tipoMime: mime,
          tamanioBytes: bytes.length,
          lectorBytes: () async => bytes,
        ),
      ],
      operationId:
          (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch)
              .toString(),
    );
    return {
      'saved': true,
      'task': await _task(await _getTask(task.id), detail: true),
      if (!notified)
        'notificationWarning':
            'Trabajo guardado. El aviso no se confirmó; puedes reintentarlo.',
    };
  }

  Future<Map<String, dynamic>> _writeProgress(
    DocumentSnapshot<Map<String, dynamic>> task,
    Map<String, dynamic> body,
  ) async {
    final comment = (body['comment'] ?? '').toString().trim();
    if (comment.isEmpty) throw StateError('Describe tu avance para guardarlo.');
    final percentage = (body['percentage'] is num)
        ? (body['percentage'] as num).toInt().clamp(0, 100)
        : 0;
    final operation =
        (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch)
            .toString();
    final notified = await activities.registrarAvance(
      actividadId: task.id,
      trabajadorId: _uid,
      comentario: comment,
      archivos: const [],
      operationId: operation,
      porcentaje: percentage.toInt(),
    );
    return {
      'saved': true,
      'task': await _task(await _getTask(task.id), detail: true),
      if (!notified)
        'notificationWarning':
            'Trabajo guardado. El aviso no se confirmó; puedes reintentarlo.',
    };
  }

  Future<Map<String, dynamic>> _complete(
    DocumentSnapshot<Map<String, dynamic>> task,
    Map<String, dynamic> body,
  ) async {
    final notified = await activities.registrarAvance(
      actividadId: task.id,
      trabajadorId: _uid,
      comentario: (body['comment'] ?? '').toString().trim(),
      archivos: const [],
      esCierre: true,
      operationId:
          (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch)
              .toString(),
    );
    return {
      'saved': true,
      'task': await _task(await _getTask(task.id), detail: true),
      if (!notified)
        'notificationWarning':
            'Trabajo guardado. El aviso no se confirmó; puedes reintentarlo.',
    };
  }

  Future<Map<String, dynamic>> _review(
    DocumentSnapshot<Map<String, dynamic>> task,
    Map<String, dynamic> body,
  ) async {
    final profile = await _profile(_uid);
    if (profile['rol'] != 'admin')
      throw StateError('Solo Administración aprueba tareas.');
    final data = task.data() ?? const <String, dynamic>{};
    if (body['submittedAt'] != null &&
        body['submittedAt'] != _timestampIso(data['completadoEn'])) {
      throw StateError('La entrega cambió. Actualiza antes de revisarla.');
    }
    final submitted = data['completadoEn'];
    DateTime? submittedAt;
    if (submitted is Timestamp) submittedAt = submitted.toDate();
    if (!['approve', 'changes'].contains(body['decision']))
      throw StateError('Revisión inválida.');
    final notified = await activities.revisarActividad(
      actividadId: task.id,
      aprobar: body['decision'] == 'approve',
      comentario: (body['comment'] ?? '').toString().trim(),
      entregaEsperada: submittedAt,
      operationId: body['operationId']?.toString(),
    );
    return {
      'saved': true,
      'task': await _task(await _getTask(task.id), detail: true),
      if (!notified)
        'notificationWarning':
            'Trabajo guardado. El aviso no se confirmó; puedes reintentarlo.',
    };
  }

  Future<Map<String, dynamic>> run(
    String action,
    Map<String, dynamic> body,
  ) async {
    final uid = _uid;
    final profile = await _profile(uid);
    if (action == 'daily-admin-overview') {
      // Verify the authenticated profile before any team-wide reads. Neither
      // a caller-supplied role nor a selected worker changes this permission.
      if (profile['rol'] != 'admin') {
        throw StateError(
          'Solo Administración consulta el avance de todo el equipo.',
        );
      }
      if ((body['viewerId'] != null && body['viewerId'] != uid) ||
          _uid != uid) {
        throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
      }
      final snapshots = await Future.wait([
        db.collection('actividades').get(),
        db.collection('usuarios').get(),
        db.collection('proyectos').get(),
        db.collection('rh_expedientes').get(),
      ]);
      final personnel = {
        for (final doc in snapshots[3].docs) doc.id: doc.data(),
      };
      _names.clear();
      final people = snapshots[1].docs.map((doc) {
        final data = doc.data();
        final name = (data['nombre'] ?? data['Nombre'] ?? 'Integrante')
            .toString();
        _names[doc.id] = name;
        return <String, dynamic>{
          'id': doc.id,
          'name': name,
          'role': (data['rol'] ?? 'trabajador').toString(),
          'active': data['activo'] != false,
          'diasDescanso':
              data['diasDescanso'] ?? personnel[doc.id]?['diasDescanso'],
          'trabajaSabados':
              data['trabajaSabados'] ?? personnel[doc.id]?['trabajaSabados'],
          'diasSinJornada':
              data['diasSinJornada'] ?? personnel[doc.id]?['diasSinJornada'],
          'department':
              (personnel[doc.id]?['area'] ??
                      data['departamento'] ??
                      data['department'] ??
                      data['area'] ??
                      '')
                  .toString(),
        };
      }).toList();
      people.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      final projects = snapshots[2].docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'title': (data['titulo'] ?? 'Proyecto').toString(),
          'status': (data['estatus'] ?? 'pendiente').toString(),
        };
      }).toList();
      projects.sort(
        (a, b) => (a['title'] as String).compareTo(b['title'] as String),
      );
      final items = <Map<String, dynamic>>[];
      // The same activity may also appear in daily/project views. Its document
      // ID remains the single source here, and progress includes legacy events
      // whose percentage could not be copied into the activity summary.
      final docs = snapshots[0].docs;
      const batchSize = 8;
      for (var start = 0; start < docs.length; start += batchSize) {
        if (_uid != uid) {
          throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
        }
        final batch = await Future.wait(
          docs
              .skip(start)
              .take(batchSize)
              .map((doc) => _task(doc, overview: true)),
        );
        for (final item in batch) {
          if (item['assignedAt'] == null) item['day'] = null;
          if (item['dueAt'] == null) item['dueDay'] = null;
          if ((item['projectId'] as String).isNotEmpty &&
              !['extra', 'instalacion', 'envio'].contains(item['workKind'])) {
            item['workKind'] = 'proyecto';
          }
          items.add(item);
        }
      }
      if (_uid != uid) {
        throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
      }
      return {
        'viewerId': uid,
        'cached': snapshots.any(
          (snapshot) =>
              snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites,
        ),
        'items': items,
        'people': people,
        'projects': projects,
      };
    }
    if (action == 'daily-create') return _create(body);
    if (action == 'daily-list') {
      final day = (body['day'] ?? '').toString();
      final docs = await _visibleDocs(
        profile,
        projectId: body['projectId']?.toString(),
      );
      final items = <Map<String, dynamic>>[];
      for (final doc in docs) {
        final data = doc.data();
        final kind = (data['workKind'] ?? 'dia').toString();
        if (body['allDates'] != true &&
            !_matches(data, day, carryPending: body['includePending'] == true))
          continue;
        if (day.length == 6) {
          if (!['instalacion', 'envio'].contains(kind)) continue;
        }
        items.add(await _task(doc));
      }
      items.sort((a, b) {
        final byDate = (a['day'] as String).compareTo(b['day'] as String);
        return byDate != 0
            ? byDate
            : (a['title'] as String).compareTo(b['title'] as String);
      });
      if (_uid != uid)
        throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
      return {
        'items': items,
        'day': day,
        'cached': docs.any((doc) => doc.metadata.isFromCache),
        'pendingSync': docs.any((doc) => doc.metadata.hasPendingWrites),
      };
    }
    final task = await _getTask((body['taskId'] ?? '').toString());
    if (action == 'daily-read')
      return {'task': await _task(task, detail: true)};
    if ((task.data()?['installationOrderId'] ?? '').toString().isNotEmpty) {
      throw StateError(
        'Abre el checklist de instalación para guardar o autorizar esta preparación.',
      );
    }
    if (action == 'daily-start') {
      await activities.iniciarActividad(
        actividadId: task.id,
        trabajadorId: uid,
      );
      return {'saved': true, 'task': await _task(await _getTask(task.id))};
    }
    if (action == 'daily-reopen') {
      final notified = await activities.reabrirActividad(
        actividadId: task.id,
        comentario: (body['comment'] ?? '').toString(),
        operationId: body['operationId']?.toString(),
      );
      return {
        'saved': true,
        'task': await _task(await _getTask(task.id), detail: true),
        if (!notified)
          'notificationWarning':
              'La tarea se reabrió. El aviso no se confirmó.',
      };
    }
    if (action == 'daily-evidence') return _writeEvidence(task, body);
    if (action == 'daily-progress') return _writeProgress(task, body);
    if (action == 'daily-complete') return _complete(task, body);
    if (action == 'daily-review') return _review(task, body);
    throw StateError('Acción de tarea no reconocida.');
  }
}
