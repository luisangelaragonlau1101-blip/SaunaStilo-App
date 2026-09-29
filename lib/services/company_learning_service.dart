import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'firestore_daily_tasks_service.dart';
import 'local_attendance_fallback.dart';

/// Authenticated company-service client.
///
/// Daily work is stored in Firestore first. This keeps tasks, evidence and
/// approvals available when the optional AppDeploy service is paused. Private
/// learning/manual actions retain the service route and its session checks.
class CompanyLearningService {
  final FirebaseAuth _auth;

  CompanyLearningService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  static final endpoint = Uri.parse(
    'https://api-v2.appdeploy.ai/app/ollin-smart-vxs23c/api/sauna',
  );
  static final directEndpoint = Uri.parse(
    'https://ollin-smart-vxs23c.v2.appdeploy.ai/api/sauna',
  );

  bool _paused(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    return response.statusCode == 402 ||
        (decoded is Map && decoded['code'] == 'APP_TEMPORARILY_UNAVAILABLE');
  }

  Future<http.Response> _post(
    Uri target,
    String token,
    String action,
    Map<String, dynamic> data,
  ) =>
      http
          .post(
            target,
            headers: {
              'Content-Type': 'application/json',
              'X-Sauna-Token': token,
            },
            body: jsonEncode({...data, 'action': action}),
          )
          .timeout(const Duration(seconds: 12));

  Future<http.Response> _remote(
    String token,
    String action,
    Map<String, dynamic> data,
  ) async {
    var response = await _post(endpoint, token, action, data);
    if (_paused(response)) {
      try {
        final direct = await _post(directEndpoint, token, action, data);
        if (!_paused(direct)) response = direct;
      } catch (_) {
        // Preserve the gateway response so the caller gets its useful status.
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Inicia sesión en Sauna Stilo.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'No se pudo validar tu sesión. Inicia sesión nuevamente.',
      );
    }

    if (action.startsWith('daily-')) {
      try {
        return await FirestoreDailyTasksService(auth: _auth).run(action, data);
      } catch (error) {
        // Existing AppDeploy tasks remain a compatibility path if a device
        // cannot read Firestore (for example, while Firebase reconnects).
        if (error is! FirebaseException) rethrow;
      }
    }

    if (action.startsWith('attendance-')) {
      try {
        return await _callRemote(user, token, action, data);
      } catch (_) {
        // Attendance remains usable on the device while the optional service
        // is paused. Every result is marked pendingSync by the fallback.
        return LocalAttendanceFallback(auth: _auth).run(action, {
          ...data,
          if (!data.containsKey('day')) 'day': _todayKey(),
        });
      }
    }

    return _callRemote(user, token, action, data);
  }

  String _todayKey() {
    // The company payroll day is always the Mexico City day, regardless of
    // the browser/device timezone.
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 6));
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _callRemote(
    User user,
    String token,
    String action,
    Map<String, dynamic> data,
  ) async {

    var response = await _remote(token, action, data);
    if (response.statusCode == 401 && _auth.currentUser?.uid == user.uid) {
      final renewed = await user.getIdToken(true);
      if (renewed != null && renewed.isNotEmpty) {
        response = await _remote(renewed, action, data);
      }
    }
    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('La sesión cambió. Abre la pantalla con tu cuenta.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw StateError(
        'El servicio no respondió correctamente. Reintenta sin salir.',
      );
    }
    if (_paused(response)) {
      throw StateError(
        'El servicio externo está pausado; las tareas nuevas ya pueden guardarse en la app. La jornada se sincronizará cuando vuelva a estar disponible.',
      );
    }
    if (response.statusCode != 200) {
      final message = decoded is Map
          ? decoded['error'] ?? decoded['message']
          : null;
      throw StateError(
        message is String
            ? message
            : 'No se confirmó la operación. Vuelve a consultar su estado.',
      );
    }
    if (decoded is! Map) {
      throw StateError('La respuesta del servicio no tiene el formato esperado.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String message(Object error) => error is StateError
      ? error.message.toString()
      : 'No se confirmó la operación. Revisa tu conexión y vuelve a intentar.';
}
