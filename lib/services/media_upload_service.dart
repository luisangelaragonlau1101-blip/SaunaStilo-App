import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MediaUploadResult {
  final String url;
  final String path;

  const MediaUploadResult({required this.url, required this.path});
}

/// Uploads user media directly to Vercel Blob using a short-lived, scoped URL.
/// The permanent Blob credential stays in Vercel and is never shipped in the
/// Flutter application.
class MediaUploadService {
  static const int maxBytesPerFile = 50 * 1024 * 1024;
  static const String _productionOrigin =
      'https://sauna-stilo-app-web.vercel.app';

  final FirebaseAuth _auth;
  final http.Client _client;
  final String? _originOverride;

  MediaUploadService({
    FirebaseAuth? auth,
    http.Client? client,
    String? origin,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _originOverride = origin;

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

    final token = await _idToken();
    final signResponse = await _client.post(
      _endpoint(),
      headers: <String, String>{
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'action': 'sign-upload',
        'fileName': fileName,
        'contentType': contentType,
        'folder': folder,
        'size': bytes.length,
      }),
    );
    final signData = _json(signResponse);
    if (signResponse.statusCode < 200 || signResponse.statusCode >= 300) {
      throw StateError(
        signData['error']?.toString() ??
            'No se pudo preparar la carga del archivo.',
      );
    }

    final uploadUrl = signData['uploadUrl']?.toString() ?? '';
    if (uploadUrl.isEmpty) {
      throw StateError('El servidor no devolvió una dirección de carga.');
    }
    final uploadResponse = await _client.put(
      Uri.parse(uploadUrl),
      headers: <String, String>{'content-type': contentType},
      body: bytes,
    );
    final uploadData = _json(uploadResponse);
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw StateError(
        uploadData['error']?.toString() ??
            'No se pudo transferir el archivo.',
      );
    }

    final url = uploadData['url']?.toString() ?? '';
    final path = uploadData['pathname']?.toString() ??
        signData['pathname']?.toString() ??
        '';
    if (url.isEmpty || path.isEmpty) {
      throw StateError('La carga terminó sin una dirección válida.');
    }
    return MediaUploadResult(url: url, path: path);
  }

  Future<void> delete({required String url, required String path}) async {
    if (url.trim().isEmpty && path.trim().isEmpty) return;
    final token = await _idToken();
    final response = await _client.delete(
      _endpoint(),
      headers: <String, String>{
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'action': 'delete',
        'url': url,
        'path': path,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _json(response);
      throw StateError(
        data['error']?.toString() ?? 'No se pudo eliminar el archivo.',
      );
    }
  }

  Future<String> _idToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para subir archivos.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No se pudo validar tu sesión. Vuelve a iniciar sesión.');
    }
    return token;
  }

  Uri _endpoint() {
    final origin = _originOverride ??
        (kIsWeb && Uri.base.host.endsWith('vercel.app')
            ? Uri.base.origin
            : _productionOrigin);
    return Uri.parse('$origin/api/media');
  }

  static Map<String, dynamic> _json(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
