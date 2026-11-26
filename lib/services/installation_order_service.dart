import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// All mutations run in authenticated server transactions, using the same
/// inventory and personal tool records as the existing warehouse module.
class InstallationOrderService {
  final FirebaseFunctions? functions;
  final FirebaseAuth? auth;
  final FirebaseStorage? storage;
  InstallationOrderService({this.functions, this.auth, this.storage});
  String operationId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final identity = auth ?? FirebaseAuth.instance;
    final uid = identity.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión.');
    final result = await (functions ?? FirebaseFunctions.instance)
        .httpsCallable(
          'enterpriseInstallations',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call<Map<String, dynamic>>({'action': action, ...data});
    if (identity.currentUser?.uid != uid)
      throw StateError('La sesión cambió. Abre de nuevo la orden.');
    return _map(result.data);
  }

  Future<Map<String, dynamic>> list({String? afterId}) =>
      call('list', {if (afterId != null) 'afterId': afterId});
  Future<Map<String, dynamic>> read(String id) => call('read', {'orderId': id});
  Future<Map<String, dynamic>> catalog({String? orderId}) =>
      call('catalog', {if (orderId != null) 'orderId': orderId});
  Future<Map<String, dynamic>> mutate(
    String action,
    String operationId,
    Map<String, dynamic> data,
  ) => call(action, {...data, 'operationId': operationId});
  Future<Map<String, dynamic>> uploadPhoto(
    String id,
    String operationId,
    Uint8List bytes,
    String name,
  ) => mutate('upload-photo', operationId, {
    'orderId': id,
    'base64': base64Encode(bytes),
    'nombre': name,
  });
  Future<Uint8List> readFile(String orderId, String path) async {
    final identity = auth ?? FirebaseAuth.instance;
    final uid = identity.currentUser?.uid;
    if (uid == null ||
        !path.startsWith('instalaciones/$orderId/') ||
        path.contains('..')) {
      throw StateError('El archivo no pertenece a esta orden.');
    }
    final bytes = await (storage ?? FirebaseStorage.instance)
        .ref(path)
        .getData(12 * 1024 * 1024);
    if (uid != identity.currentUser?.uid) throw StateError('La sesión cambió.');
    if (bytes == null) throw StateError('El archivo no está disponible.');
    return bytes;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  static String message(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FirebaseFunctionsException) {
      if (error.code == 'not-found' || error.code == 'unimplemented')
        return 'El servicio de instalaciones necesita publicarse en Firebase. Tus registros anteriores siguen conservados.';
      return error.message ??
          'No se confirmó la operación. Actualiza antes de reintentar.';
    }
    return 'No se confirmó la operación. Revisa tu conexión y vuelve a intentar.';
  }
}

List<Map<String, dynamic>> installationRows(dynamic raw) => raw is List
    ? raw.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
    : [];
Map<String, dynamic> installationMap(dynamic raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : {};
String installationStatus(String state) =>
    const {
      'preparacion': 'Preparando',
      'lista': 'Por autorizar',
      'autorizada': 'Salida por firmar',
      'validacion_administrativa': 'Confirmación administrativa',
      'en_instalacion': 'En instalación',
      'devolucion': 'Regreso por firmar',
      'diferencias': 'Regreso por conciliar',
      'cerrada': 'Cerrada',
      'cancelada': 'Cancelada',
    }[state] ??
    state;
