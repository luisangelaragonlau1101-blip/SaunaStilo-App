import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first receipt queue used only while the optional attendance service
/// is unavailable. It never presents a pending receipt as a server sync.
class LocalAttendanceFallback {
  final FirebaseAuth auth;
  final FirebaseFirestore db;

  LocalAttendanceFallback({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
      : auth = firebaseAuth ?? FirebaseAuth.instance,
        db = firestore ?? FirebaseFirestore.instance;

  String get _uid {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('Inicia sesión en Sauna Stilo.');
    return uid;
  }

  String _key(String day) => 'sauna.attendance.pending.$_uid.$day';

  Future<Map<String, dynamic>> _local(String day) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(day));
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _save(String day, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(day), jsonEncode(data));
  }

  Future<Map<String, dynamic>> _server(String day) async {
    try {
      final snapshot = await db.collection('asistencias').doc('${_uid}_$day').get();
      return snapshot.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> state(String day) async {
    final server = await _server(day);
    final local = await _local(day);
    final data = {...server, ...local};
    return {
      'supportsManual': true,
      'supportsPauses': true,
      'pendingSync': local.isNotEmpty,
      'asistenciaId': '${_uid}_$day',
      'day': day,
      'receiptRevision': '${data['revision'] ?? 0}',
      'data': data,
      'exito': true,
      'mensaje': local.isNotEmpty ? 'Guardado en este dispositivo; queda pendiente de sincronizar.' : null,
    };
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<Map<String, dynamic>> record(String day, String movement) async {
    final current = await state(day);
    final data = Map<String, dynamic>.from(current['data'] as Map? ?? {});
    final field = <String, String>{
      'entrada': 'horaEntrada',
      'salida_comida': 'salidaComidaReal',
      'regreso_comida': 'regresoComidaReal',
      'salida': 'horaSalida',
    }[movement];
    if (field == null) throw StateError('Movimiento de jornada inválido.');
    if (data[field] != null) return {...current, 'yaRegistrada': true};
    if (movement == 'entrada') {
      data['trabajadorId'] = _uid;
      data['fecha'] = _now();
      data['estatus'] = 'a_tiempo';
      data['estatusComida'] = 'ninguna';
    } else if (data['horaEntrada'] == null) {
      throw StateError('Primero registra tu entrada de hoy.');
    } else if (movement == 'salida_comida') {
      data['estatusComida'] = 'comiendo';
    } else if (movement == 'regreso_comida' && data['salidaComidaReal'] == null) {
      throw StateError('Registra primero tu salida a comer.');
    }
    data[field] = _now();
    data['revision'] = (data['revision'] is num ? (data['revision'] as num).toInt() : 0) + 1;
    await _save(day, data);
    return {...await state(day), 'exito': true, 'mensaje': 'Hora guardada en este dispositivo; queda pendiente de sincronizar.'};
  }

  Future<Map<String, dynamic>> pause(String day, Map<String, dynamic> body) async {
    final current = await state(day);
    final data = Map<String, dynamic>.from(current['data'] as Map? ?? {});
    final pauses = (data['pausasJornada'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (body['direction'] == 'out') {
      if (data['horaEntrada'] == null) throw StateError('Primero registra tu entrada de hoy.');
      if (pauses.any((item) => item['regreso'] == null)) throw StateError('Ya tienes una pausa abierta.');
      final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
      pauses.add({'id': id, 'tipo': body['kind'] ?? 'otro', 'descripcion': body['detail'] ?? '', 'salida': _now(), 'regreso': null});
    } else {
      final id = body['pauseId']?.toString();
      final index = pauses.indexWhere((item) => item['id'] == id && item['regreso'] == null);
      if (index < 0) throw StateError('No se encontró esa pausa.');
      pauses[index]['regreso'] = _now();
    }
    data['pausasJornada'] = pauses;
    data['revision'] = (data['revision'] is num ? (data['revision'] as num).toInt() : 0) + 1;
    await _save(day, data);
    return {...await state(day), 'exito': true, 'mensaje': 'Pausa guardada en este dispositivo; queda pendiente de sincronizar.'};
  }

  Future<Map<String, dynamic>> run(String action, Map<String, dynamic> body) async {
    final day = (body['day'] ?? '').toString();
    if (day.isEmpty) throw StateError('Día de jornada inválido.');
    if (action == 'attendance-state') return state(day);
    if (action == 'attendance-record') return record(day, (body['movement'] ?? '').toString());
    if (action == 'attendance-pause') return pause(day, body);
    if (action == 'attendance-history') {
      final days = (body['days'] as List? ?? const []).whereType<String>();
      return {'items': [for (final selected in days) await state(selected)]};
    }
    if (action == 'attendance-approve') {
      throw StateError(
        'La autorización de comida necesita conexión con Administración. La jornada local sigue guardada.',
      );
    }
    if (action == 'attendance-sync-page') return {'day': day, 'updated': 0, 'nextToken': null};
    throw StateError('Acción de jornada no reconocida.');
  }
}
