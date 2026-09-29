import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/evidencia_actividad_model.dart';
import 'actividades_service.dart';
import 'notificaciones_service.dart';

/// Firestore fallback for the daily-work hub.
///
/// The first version of the hub used the AppDeploy service for daily tasks.
/// That service can be paused independently of Firebase. Project activities
/// already use Firestore, so this adapter keeps the same response shape as the
/// hub while saving the work in the app's existing activity collections.
class FirestoreDailyTasksService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  late final ActividadesService activities =
      ActividadesService(firestore: db, auth: auth);

  FirestoreDailyTasksService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
      : db = firestore ?? FirebaseFirestore.instance,
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
    final local = date.toLocal();
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
    if (parsed == null) throw StateError('Selecciona una fecha válida.');
    return parsed;
  }

  String _status(Map<String, dynamic> data) {
    final value = (data['estatus'] ?? 'pendiente')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (value == 'completada' ||
        value == 'completed' ||
        value == 'finalizado' ||
        value == 'finalizada' ||
        value == 'terminado' ||
        value == 'terminada') {
      return 'completado';
    }
    if (value == 'en_proceso' || value == 'progreso') return 'en_progreso';
    return value.isEmpty ? 'pendiente' : value;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _visibleDocs(
    Map<String, dynamic> profile,
  ) async {
    final role = profile['rol'];
    final collection = db.collection('actividades');
    if (role == 'admin') return (await collection.get()).docs;
    // This predicate is also the ownership predicate in Firestore rules, so
    // the query remains readable for regular team profiles.
    return (await collection
            .where('asignadoATrabajadorId', isEqualTo: _uid)
            .get())
        .docs;
  }

  bool _matches(Map<String, dynamic> data, String requestedDay) {
    if (requestedDay.length == 6) {
      final assigned = _dayKey(data['fechaAsignada'] ?? data['fechaInicio']);
      return assigned.startsWith(requestedDay);
    }
    return _dayKey(data['fechaAsignada'] ?? data['fechaInicio']) == requestedDay;
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
  }) async {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final status = _status(data);
    final evidence = detail
        ? await _evidence(snapshot.id)
        : const <EvidenciaActividad>[];
    final progress = detail ? await _progress(snapshot.id) : const <AvanceActividad>[];
    final latest = progress.isEmpty ? null : progress.first;
    var percentage = 0;
    if (latest != null) {
      final raw = await db
          .collection('actividades')
          .doc(snapshot.id)
          .collection('avances')
          .doc(latest.id)
          .get();
      final value = raw.data()?['porcentaje'];
      if (value is num) percentage = value.toInt().clamp(0, 100).toInt();
    }
    if (percentage == 0 && (status == 'en_revision' || status == 'completado')) {
      percentage = 100;
    }
    final assignedId = (data['asignadoATrabajadorId'] ?? '').toString();
    final assigned = assignedId.isEmpty
        ? const <String, dynamic>{'nombre': 'Integrante'}
        : await _profile(assignedId);
    final creatorId = (data['creadoPor'] ?? '').toString();
    Map<String, dynamic>? creator;
    if (creatorId.isNotEmpty) {
      try {
        creator = await _profile(creatorId);
      } catch (_) {
        creator = null;
      }
    }
    AvanceActividad? submission;
    for (final item in progress) {
      if (item.esCierre) {
        submission = item;
        break;
      }
    }
    return {
      'taskId': snapshot.id,
      'day': _dayKey(data['fechaAsignada'] ?? data['fechaInicio']),
      'title': (data['titulo'] ?? 'Tarea').toString(),
      'details': (data['descripcion'] ?? '').toString(),
      'workKind': (data['workKind'] ?? 'dia').toString(),
      'userId': data['asignadoATrabajadorId'] ?? '',
      'userName': assigned['nombre'],
      'createdBy': creatorId,
      'createdByName': creator?['nombre'] ?? 'Administración',
      'status': status,
      'percentage': percentage,
      'evidenceCount': (data['evidenciasCount'] ?? data['cantidadEvidencias'] ?? evidence.length) is num
          ? ((data['evidenciasCount'] ?? data['cantidadEvidencias'] ?? evidence.length) as num).toInt()
          : evidence.length,
      // Keep the response contract independent of the Firestore field names;
      // the Flutter detail view can open both inline photos and uploaded URLs.
      'evidence': evidence
          .map((item) => {
                'id': item.id,
                'url': item.url,
                'name': item.nombre,
                'contentType': item.tipoMime,
                'size': item.tamanioBytes,
                'storagePath': item.storagePath,
                'createdAt': item.creadoEn.toIso8601String(),
              })
          .toList(),
      'submissionId': submission?.id,
      'submittedAt': submission?.fecha.toIso8601String(),
      'reviewComment': (data['observacionesAdmin'] ?? '').toString(),
      'history': progress
          .map((item) => {
                'id': item.id,
                'kind': item.esCierre ? 'submitted' : 'progress',
                'comment': item.comentario,
                'at': item.fecha.toIso8601String(),
                'actorName': item.trabajadorId == _uid ? assigned['nombre'] : 'Equipo',
              })
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
    if (profile['rol'] != 'admin' && profile['rol'] != 'maestro') {
      throw StateError('Solo administradores y maestros asignan tareas.');
    }
    final title = (body['title'] ?? '').toString().trim();
    if (title.length < 3 || title.length > 150) {
      throw StateError('Escribe un título de 3 a 150 caracteres.');
    }
    final targetId = (body['userId'] ?? '').toString();
    final target = await _profile(targetId);
    final day = _parseDay((body['day'] ?? '').toString());
    final due = DateTime.tryParse((body['dueAt'] ?? '').toString()) ??
        DateTime(day.year, day.month, day.day, 19);
    final operation = (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch).toString();
    final docId = 'daily_${uid}_$operation';
    final ref = db.collection('actividades').doc(docId);
    final old = await ref.get();
    if (!old.exists) {
      await ref.set({
        'proyectoId': '',
        'titulo': title,
        'descripcion': (body['details'] ?? '').toString().trim(),
        'asignadoATrabajadorId': targetId,
        'fechaInicio': Timestamp.fromDate(day),
        'fechaAsignada': Timestamp.fromDate(day),
        'fechaTermino': Timestamp.fromDate(due),
        'completadoEn': null,
        'estatus': 'pendiente',
        'observacionesAdmin': '',
        'comentariosTrabajador': '',
        'evidenciaFotos': <String>[],
        'historialEventos': <Map<String, dynamic>>[],
        'evidenciasCount': 0,
        'cantidadEvidencias': 0,
        'ultimoAvance': null,
        'requiereEvidencia': true,
        'workKind': (body['workKind'] ?? 'dia').toString(),
        'creadoPor': uid,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      try {
        await db.collection('notificaciones').doc('tarea_$docId').set(
          NotificacionesService.datosAviso(
            titulo: 'Nueva tarea asignada',
            mensaje: title,
            tipo: 'tarea',
            destinatarioId: targetId,
          )..addAll({'actividadId': docId, 'proyectoId': ''}),
        );
      } catch (_) {
        // The task is already durable; notification delivery can be retried.
      }
    }
    return {'saved': true, 'task': await _task(await ref.get()), 'target': target['nombre']};
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
    await activities.registrarAvance(
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
      operationId: (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
    );
    return {'saved': true, 'task': await _task(await _getTask(task.id), detail: true)};
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
    final operation = (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch).toString();
    await activities.registrarAvance(
      actividadId: task.id,
      trabajadorId: _uid,
      comentario: comment,
      archivos: const [],
      operationId: operation,
    );
    await db
        .collection('actividades')
        .doc(task.id)
        .collection('avances')
        .doc(operation)
        .set({'porcentaje': percentage}, SetOptions(merge: true));
    return {'saved': true, 'task': await _task(await _getTask(task.id), detail: true)};
  }

  Future<Map<String, dynamic>> _complete(
    DocumentSnapshot<Map<String, dynamic>> task,
    Map<String, dynamic> body,
  ) async {
    await activities.registrarAvance(
      actividadId: task.id,
      trabajadorId: _uid,
      comentario: (body['comment'] ?? '').toString().trim(),
      archivos: const [],
      esCierre: true,
      operationId: (body['operationId'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
    );
    return {'saved': true, 'task': await _task(await _getTask(task.id), detail: true)};
  }

  Future<Map<String, dynamic>> _review(
    DocumentSnapshot<Map<String, dynamic>> task,
    Map<String, dynamic> body,
  ) async {
    final profile = await _profile(_uid);
    if (profile['rol'] != 'admin') throw StateError('Solo Administración aprueba tareas.');
    final data = task.data() ?? const <String, dynamic>{};
    final submitted = data['completadoEn'];
    DateTime? submittedAt;
    if (submitted is Timestamp) submittedAt = submitted.toDate();
    if (submittedAt == null) throw StateError('La tarea todavía no tiene una entrega.');
    await activities.revisarActividad(
      actividadId: task.id,
      aprobar: body['decision'] == 'approve',
      comentario: (body['comment'] ?? '').toString().trim(),
      entregaEsperada: submittedAt,
    );
    return {'saved': true, 'task': await _task(await _getTask(task.id), detail: true)};
  }

  Future<Map<String, dynamic>> run(String action, Map<String, dynamic> body) async {
    final profile = await _profile(_uid);
    if (action == 'daily-create') return _create(body);
    if (action == 'daily-list') {
      final day = (body['day'] ?? '').toString();
      final docs = await _visibleDocs(profile);
      final items = <Map<String, dynamic>>[];
      for (final doc in docs) {
        final data = doc.data();
        final kind = (data['workKind'] ?? 'dia').toString();
        if (!_matches(data, day)) continue;
        if (day.length == 6) {
          if (!['instalacion', 'envio'].contains(kind)) continue;
        } else if (!['dia', 'extra'].contains(kind)) {
          continue;
        }
        items.add(await _task(doc));
      }
      return {'items': items, 'day': day};
    }
    final task = await _getTask((body['taskId'] ?? '').toString());
    if (action == 'daily-read') return {'task': await _task(task, detail: true)};
    if (action == 'daily-evidence') return _writeEvidence(task, body);
    if (action == 'daily-progress') return _writeProgress(task, body);
    if (action == 'daily-complete') return _complete(task, body);
    if (action == 'daily-review') return _review(task, body);
    throw StateError('Acción de tarea no reconocida.');
  }
}
