import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

typedef AttendanceLocationReader = Future<Map<String, double>> Function();
typedef AttendanceProfileReader = Future<Map<String, dynamic>?> Function(String uid);
typedef AttendanceCallableInvoker = Future<Object?> Function(Map<String, dynamic> payload);

/// The client chooses a device proof; the server independently authorizes it.
/// A manual button is a user action, never permission to bypass a GPS policy.
class AttendanceDeviceProof {
  static Future<Map<String, dynamic>> prepare({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> request,
    required AttendanceLocationReader readLocation,
  }) async {
    final lat = request['latitud'], lng = request['longitud'];
    if (lat is num && lng is num && lat.isFinite && lng.isFinite &&
        lat.abs() <= 90 && lng.abs() <= 180) {
      return {'manual': false, 'latitud': lat.toDouble(), 'longitud': lng.toDouble()};
    }
    if (profile['asistenciaManualPermitida'] == true) return {'manual': true};
    final coordinates = await readLocation();
    final latitude = coordinates['latitud'], longitude = coordinates['longitud'];
    if (latitude == null || longitude == null || !latitude.isFinite ||
        !longitude.isFinite || latitude.abs() > 90 || longitude.abs() > 180) {
      throw StateError('No se obtuvo una ubicación válida. Reintenta desde el dispositivo.');
    }
    return {'manual': false, ...coordinates};
  }
}

/// Attendance stays on Firebase. A failed write never switches to another
/// database or becomes a successful device-only attendance record.
class FirebaseAttendanceService {
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  final AttendanceLocationReader _readLocation;
  final String? Function()? _currentUidOverride;
  final AttendanceProfileReader? _readProfileOverride;
  final AttendanceCallableInvoker? _invokeOverride;
  FirebaseAttendanceService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AttendanceLocationReader? readLocation,
    String? Function()? currentUid,
    AttendanceProfileReader? readProfile,
    AttendanceCallableInvoker? invoke,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _functionsOverride = functions,
       _readLocation = readLocation ?? deviceLocation,
       _currentUidOverride = currentUid,
       _readProfileOverride = readProfile,
       _invokeOverride = invoke;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  String? get _uid => _currentUidOverride != null ? _currentUidOverride!() : _auth.currentUser?.uid;

  static Future<Map<String, double>> deviceLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Activa la ubicación para registrar tu jornada.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Permite la ubicación del dispositivo o consulta a Administración sobre el registro manual.');
    }
    final location = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
    if (DateTime.now().difference(location.timestamp).abs() > const Duration(minutes: 1) ||
        !location.accuracy.isFinite || location.accuracy > 60) {
      throw StateError('La ubicación no es suficientemente precisa. Acércate a una zona abierta y reintenta.');
    }
    return {'latitud': location.latitude, 'longitud': location.longitude};
  }

  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> request) async {
    final uid = _uid;
    if (uid == null) throw StateError('Inicia sesión en Sauna Stilo.');
    final payload = <String, dynamic>{...request, 'action': action};
    if (action == 'attendance-record' || action == 'attendance-pause') {
      final profile = _readProfileOverride != null
          ? await _readProfileOverride!(uid)
          : (await _db.collection('usuarios').doc(uid).get()).data();
      if (_uid != uid) throw StateError('La sesión cambió. Abre de nuevo Mi jornada.');
      if (profile == null || profile['activo'] == false) {
        throw StateError('Tu cuenta no tiene acceso al registro de jornada.');
      }
      final proof = await AttendanceDeviceProof.prepare(
        profile: profile, request: request, readLocation: _readLocation,
      );
      if (_uid != uid) throw StateError('La sesión cambió. No se registró el movimiento.');
      payload.remove('manual');
      payload.remove('latitud');
      payload.remove('longitud');
      payload.addAll(proof);
      if (payload['direction'] == 'return') payload['direction'] = 'in';
    }
    final Object? data;
    if (_invokeOverride != null) {
      data = await _invokeOverride!(payload);
    } else {
      final response = await (_functionsOverride ?? FirebaseFunctions.instance)
          .httpsCallable('enterpriseAttendance', options: HttpsCallableOptions(timeout: const Duration(seconds: 35)))
          .call<Object?>(payload);
      data = response.data;
    }
    if (_uid != uid) throw StateError('La sesión cambió. Consulta el registro con tu cuenta.');
    if (data is! Map) throw StateError('El servidor no confirmó un registro válido. Actualiza Mi jornada.');
    return Map<String, dynamic>.from(data);
  }
}
