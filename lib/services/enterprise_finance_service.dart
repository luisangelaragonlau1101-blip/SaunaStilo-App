import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Enterprise writes use authenticated server transactions and operation keys.
/// Fiscal files are never published as token-bearing download URLs.
class EnterpriseFinanceService {
  EnterpriseFinanceService({FirebaseFunctions? functions, FirebaseAuth? auth, FirebaseStorage? storage})
      : _functions = functions, _auth = auth, _storage = storage;
  final FirebaseFunctions? _functions;
  final FirebaseAuth? _auth;
  final FirebaseStorage? _storage;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;

  Stream<String?> get sessionChanges => auth.authStateChanges().map((user) => user?.uid);

  static String operationId() => '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';

  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> data = const {}]) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión.');
    final result = await (_functions ?? FirebaseFunctions.instance).httpsCallable('enterpriseFinance', options: HttpsCallableOptions(timeout: const Duration(seconds: 65))).call<Object?>({'action': action, ...data});
    if (auth.currentUser?.uid != uid) throw StateError('La sesión cambió. Abre de nuevo esta pantalla.');
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> upload({required Uint8List bytes, required String name, required String operation}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión.');
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) throw StateError('El archivo puede pesar hasta 10 MB.');
    final ext = name.split('.').last.toLowerCase();
    final mime = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'pdf': 'application/pdf', 'xml': 'application/xml'}[ext];
    if (mime == null) throw StateError('Selecciona una fotografía, PDF o XML.');
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'finance/$uid/$operation/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await (_storage ?? FirebaseStorage.instance).ref(path).putData(bytes, SettableMetadata(contentType: mime, customMetadata: {'ownerUid': uid}));
    if (auth.currentUser?.uid != uid) throw StateError('La sesión cambió. El archivo no se adjuntó a ningún registro.');
    return {'path': path, 'name': safeName, 'contentType': mime};
  }

  Future<Uint8List> readFile(String path) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || !path.startsWith('finance/')) throw StateError('El archivo no está disponible.');
    final bytes = await (_storage ?? FirebaseStorage.instance).ref(path).getData(10 * 1024 * 1024);
    if (bytes == null || auth.currentUser?.uid != uid) throw StateError('No se pudo abrir el archivo con esta sesión.');
    return bytes;
  }

  static String message(Object e) {
    if (e is StateError) return e.message.toString();
    if (e is FirebaseFunctionsException) return e.message ?? 'No se confirmó el registro. Reintenta desde el mismo formulario.';
    if (e is FirebaseException && e.code == 'permission-denied') return 'Tu sesión no tiene permiso. Administración debe revisar tu función y las reglas publicadas.';
    return 'No se confirmó la operación. Revisa tu conexión y vuelve a intentar con este formulario.';
  }
}
