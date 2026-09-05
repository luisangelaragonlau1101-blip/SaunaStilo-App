import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

class AdminVoiceStatus {
  final bool configured;
  final bool enabled;
  final String provider;
  final String message;
  final String? updatedAt;

  const AdminVoiceStatus({
    required this.configured,
    required this.enabled,
    required this.provider,
    required this.message,
    this.updatedAt,
  });

  factory AdminVoiceStatus.fromMap(Map<String, dynamic> data) {
    return AdminVoiceStatus(
      configured: data['configured'] == true,
      enabled: data['enabled'] == true,
      provider: data['provider']?.toString() ?? 'google-cloud-tts',
      message: data['message']?.toString() ?? 'Estado de voz no disponible.',
      updatedAt: data['updatedAt']?.toString(),
    );
  }
}

class AdminVoiceAudio {
  final Uint8List bytes;
  final String mimeType;

  const AdminVoiceAudio({required this.bytes, required this.mimeType});
}

class CustomVoiceException implements Exception {
  final String message;
  const CustomVoiceException(this.message);
  @override
  String toString() => message;
}

class CustomVoiceService {
  CustomVoiceService()
      : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<AdminVoiceStatus> status() async {
    try {
      final result = await _functions
          .httpsCallable(
            'getAdminVoiceStatus',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
          )
          .call();
      final raw = result.data;
      if (raw is! Map) {
        throw const CustomVoiceException('No se pudo leer el estado de la voz.');
      }
      return AdminVoiceStatus.fromMap(Map<String, dynamic>.from(raw));
    } on FirebaseFunctionsException catch (error) {
      throw CustomVoiceException(_messageFor(error));
    }
  }

  Future<AdminVoiceStatus> enroll({
    required String consentUrl,
    required String referenceUrl,
    String languageCode = 'es-US',
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'enrollAdminVoice',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
          )
          .call(<String, dynamic>{
            'consentUrl': consentUrl,
            'referenceUrl': referenceUrl,
            'languageCode': languageCode,
          });
      final raw = result.data;
      if (raw is! Map) {
        throw const CustomVoiceException(
          'El servidor no confirmó la creación de la voz.',
        );
      }
      return AdminVoiceStatus.fromMap(Map<String, dynamic>.from(raw));
    } on FirebaseFunctionsException catch (error) {
      throw CustomVoiceException(_messageFor(error));
    }
  }

  Future<AdminVoiceStatus> setEnabled(bool enabled) async {
    try {
      final result = await _functions
          .httpsCallable(
            'setAdminVoiceEnabled',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
          )
          .call(<String, dynamic>{'enabled': enabled});
      final raw = result.data;
      if (raw is! Map) {
        throw const CustomVoiceException('No se pudo actualizar la voz.');
      }
      return AdminVoiceStatus.fromMap(Map<String, dynamic>.from(raw));
    } on FirebaseFunctionsException catch (error) {
      throw CustomVoiceException(_messageFor(error));
    }
  }

  Future<AdminVoiceAudio?> synthesize(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    try {
      final result = await _functions
          .httpsCallable(
            'synthesizeAdminVoice',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
          )
          .call(<String, dynamic>{'text': clean});
      final raw = result.data;
      if (raw is! Map) return null;
      final data = Map<String, dynamic>.from(raw);
      if (data['available'] != true) return null;
      final encoded = data['audioBase64']?.toString() ?? '';
      if (encoded.isEmpty) return null;
      return AdminVoiceAudio(
        bytes: base64Decode(encoded),
        mimeType: data['mimeType']?.toString() ?? 'audio/mpeg',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' ||
          error.code == 'not-found' ||
          error.code == 'unimplemented') {
        return null;
      }
      throw CustomVoiceException(_messageFor(error));
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    return switch (error.code) {
      'unauthenticated' => 'Inicia sesión para usar la voz de Sauna Stilo.',
      'permission-denied' =>
        'Solo administración puede configurar la voz oficial.',
      'failed-precondition' =>
        'La voz personalizada todavía no está habilitada en Google Cloud para este proyecto.',
      'resource-exhausted' =>
        'El servicio de voz alcanzó temporalmente su límite de uso.',
      'invalid-argument' =>
        'La grabación no cumple el formato o la duración requeridos.',
      'deadline-exceeded' =>
        'El servicio de voz tardó demasiado. Intenta de nuevo.',
      _ => 'No se pudo conectar con el servicio de voz personalizada.',
    };
  }
}
