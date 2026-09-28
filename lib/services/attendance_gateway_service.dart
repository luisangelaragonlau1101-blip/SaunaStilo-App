import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asistencia_model.dart';
import 'company_learning_service.dart';

/// Server-confirmed attendance receipts share the app's existing authenticated
/// backend. Administrative synchronization uses the administrator's own session.
class AttendanceGatewayService {
  final CompanyLearningService api;
  AttendanceGatewayService({CompanyLearningService? api})
      : api = api ?? CompanyLearningService();

  static final _changes = StreamController<void>.broadcast();
  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  static DateTime get today => DateTime.now().toUtc().subtract(const Duration(hours: 6));
  static Map<String, dynamic> decodeDay(Map<String, dynamic> result) {
    final data = Map<String, dynamic>.from(result['data'] as Map? ?? {});
    for (final field in ['fecha', 'horaEntrada', 'horaSalida', 'salidaComidaSolicitada', 'salidaComidaReal', 'regresoComidaReal']) {
      final value = data[field];
      if (value is String) {
        final date = DateTime.tryParse(value);
        if (date == null) throw StateError('El servidor devolvió una hora inválida.');
        data[field] = Timestamp.fromDate(date);
      }
    }
    return {...result, 'data': data};
  }

  Future<Map<String, dynamic>> loadDay(String userId, {String? day}) async =>
      decodeDay(await api.call('attendance-state', {'userId': userId, if (day != null) 'day': day}));

  Stream<T> _watch<T>(Future<T> Function() load) {
    late StreamController<T> controller;
    Timer? timer;
    StreamSubscription<void>? changes;
    var busy = false;
    var reload = false;
    var cancelled = false;
    Future<void> refresh() async {
      if (cancelled || controller.isClosed) return;
      if (busy) { reload = true; return; }
      busy = true;
      try {
        final value = await load();
        if (!cancelled && !controller.isClosed) controller.add(value);
      } catch (error, stack) {
        if (!cancelled && !controller.isClosed) controller.addError(error, stack);
      } finally {
        busy = false;
        if (reload && !cancelled && !controller.isClosed) { reload = false; unawaited(refresh()); }
      }
    }
    controller = StreamController<T>(onListen: () {
      unawaited(refresh());
      timer = Timer.periodic(const Duration(seconds: 45), (_) => unawaited(refresh()));
      changes = _changes.stream.listen((_) => unawaited(refresh()));
    }, onCancel: () { cancelled = true; timer?.cancel(); changes?.cancel(); });
    return controller.stream;
  }

  Stream<Map<String, dynamic>> watchDay(String userId, {String? day}) =>
      _watch(() => loadDay(userId, day: day));

  static void refresh() => _changes.add(null);

  Future<Map<String, dynamic>> record(String movement, {double? latitude, double? longitude}) async {
    final result = decodeDay(await api.call('attendance-record', {
      'movement': movement,
      if (latitude != null) 'latitud': latitude,
      if (longitude != null) 'longitud': longitude,
    }));
    if (result['exito'] != true) throw StateError('El servidor no confirmó el registro. Actualiza tu jornada antes de reintentar.');
    refresh();
    return result;
  }

  Future<List<AsistenciaModel>> history(String userId, DateTime start, DateTime end) async {
    final days = <String>[];
    final lastDay = dayKey(today);
    for (var day = DateTime(start.year, start.month, start.day);
        !day.isAfter(end) && days.length < 7; day = day.add(const Duration(days: 1))) {
      if (dayKey(day).compareTo(lastDay) <= 0) days.add(dayKey(day));
    }
    if (days.isEmpty) return [];
    final response = await api.call('attendance-history', {'userId': userId, 'days': days});
    return (response['items'] as List).map((item) => decodeDay(Map<String, dynamic>.from(item as Map)))
        .where((item) => (item['data'] as Map).isNotEmpty)
        .map((item) => AsistenciaModel.fromData(item['asistenciaId'] as String, item['data'] as Map<String, dynamic>)).toList();
  }

  Stream<List<AsistenciaModel>> watchHistory(String userId, DateTime start, DateTime end) =>
      _watch(() => history(userId, start, end));

  Future<void> syncDay(String day) async {
    String? cursor;
    final seen = <String>{};
    do {
      final response = await api.call('attendance-sync-page', {'day': day, if (cursor != null) 'cursor': cursor});
      cursor = response['nextToken'] as String?;
      if (cursor != null && !seen.add(cursor)) throw StateError('No terminó la actualización de las jornadas. Vuelve a intentar.');
    } while (cursor != null);
    refresh();
  }

  Future<void> syncPeriod(DateTime start, DateTime end) async {
    if (end.difference(start).inDays > 31) throw StateError('Actualiza como máximo un mes a la vez.');
    for (var day = DateTime(start.year, start.month, start.day); !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      if (dayKey(day).compareTo(dayKey(today)) <= 0) await syncDay(dayKey(day));
    }
  }

  Future<void> approveMeal(String userId, String day) async {
    final result = await api.call('attendance-approve', {'userId': userId, 'day': day});
    if (result['exito'] != true) throw StateError('No se confirmó la autorización de comida.');
    refresh();
  }
}
