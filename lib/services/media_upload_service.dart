import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MediaUploadResult {
  final String url;
  final String path;

  const MediaUploadResult({required this.url, required this.path});
}

/// Stores authenticated user media directly in Firebase Storage.
///
/// Every object is kept below `media/<uid>/`, which lets this service verify
/// ownership before deleting it and avoids depending on a separate upload API.
class MediaUploadService {
  static const int maxBytesPerFile = 50 * 1024 * 1024;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static int _uploadSequence = 0;

  MediaUploadService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  Future<MediaUploadResult> upload({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('El archivo está vacío.');
    }
    if (bytes.length > maxBytesPerFile) {
      throw ArgumentError(
        'Cada archivo puede pesar hasta 50 MB. Puedes subir todos los archivos que necesites.',
      );
    }

    final user = _requireUser();
    final safeFolder = _safeFolder(folder);
    final safeName = _safeFileName(fileName);
    final uniquePart =
        '${DateTime.now().microsecondsSinceEpoch}_${_uploadSequence++}';
    final path = <String>[
      'media',
      user.uid,
      if (safeFolder.isNotEmpty) safeFolder,
      '${uniquePart}_$safeName',
    ].join('/');

    final reference = _storage.ref(path);
    final snapshot = await reference.putData(
      bytes,
      SettableMetadata(
        contentType: _safeContentType(contentType),
        customMetadata: <String, String>{
          'ownerUid': user.uid,
          'originalFileName': safeName,
        },
      ),
    );
    final url = await snapshot.ref.getDownloadURL();
    return MediaUploadResult(url: url, path: snapshot.ref.fullPath);
  }

  Future<void> delete({required String url, required String path}) async {
    final cleanUrl = url.trim();
    final cleanPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (cleanUrl.isEmpty && cleanPath.isEmpty) return;

    final user = _requireUser();
    Reference? reference;

    if (cleanPath.isNotEmpty) {
      if (!_isOwnedPath(cleanPath, user.uid)) {
        throw StateError('No tienes permiso para eliminar ese archivo.');
      }
      reference = _storage.ref(cleanPath);
    }

    if (cleanUrl.isNotEmpty) {
      final Reference urlReference;
      try {
        urlReference = _storage.refFromURL(cleanUrl);
      } on Object {
        throw ArgumentError('La dirección del archivo no es válida.');
      }
      if (!_isOwnedPath(urlReference.fullPath, user.uid)) {
        throw StateError('No tienes permiso para eliminar ese archivo.');
      }
      if (reference != null && reference.fullPath != urlReference.fullPath) {
        throw StateError('La dirección y la ruta del archivo no coinciden.');
      }
      reference = urlReference;
    }

    await reference!.delete();
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para subir archivos.');
    }
    return user;
  }

  static bool _isOwnedPath(String path, String uid) =>
      path.startsWith('media/$uid/');

  static String _safeFolder(String value) => value
      .trim()
      .split(RegExp(r'[/\\]+'))
      .map(_safeFolderSegment)
      .where((part) => part.isNotEmpty)
      .take(8)
      .join('/');

  static String _safeFolderSegment(String value) {
    var safe = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
    if (safe.length > 60) safe = safe.substring(0, 60);
    return safe;
  }

  static String _safeFileName(String value) {
    var safe = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceFirst(RegExp(r'^\.+'), '');
    if (safe.length > 120) safe = safe.substring(safe.length - 120);
    return safe.isEmpty ? 'archivo' : safe;
  }

  static String _safeContentType(String value) {
    final normalized = value.split(';').first.trim().toLowerCase();
    return normalized.isEmpty ? 'application/octet-stream' : normalized;
  }
}
