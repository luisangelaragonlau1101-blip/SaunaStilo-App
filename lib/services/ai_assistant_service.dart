import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

class AiAssistantException implements Exception {
  final String message;
  const AiAssistantException(this.message);

  @override
  String toString() => message;
}

class AiAssistantSource {
  final String title;
  final String url;

  const AiAssistantSource({required this.title, required this.url});

  factory AiAssistantSource.fromMap(Map<String, dynamic> data) {
    final rawTitle = data['titulo']?.toString().trim() ?? '';
    return AiAssistantSource(
      title: rawTitle.isEmpty ? 'Fuente web' : rawTitle,
      url: data['url']?.toString().trim() ?? '',
    );
  }
}

class AiAssistantResponse {
  final String respuesta;
  final String modelo;
  final bool usoInternet;
  final List<AiAssistantSource> fuentes;

  const AiAssistantResponse({
    required this.respuesta,
    required this.modelo,
    required this.usoInternet,
    required this.fuentes,
  });
}

class AiAssistantService {
  AiAssistantService()
      : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  static final Uri _onlineSmartEndpoint = Uri.parse(
    'https://ollin-smart-vxs23c.v2.appdeploy.ai/api/chat',
  );

  final FirebaseFunctions _functions;

  Future<String> responder({
    required String pregunta,
    required List<Map<String, String>> historial,
    List<String> imagenes = const <String>[],
    List<String> audios = const <String>[],
    bool usarInternet = true,
    String modo = 'asistente',
    String rol = 'usuario',
  }) async {
    final response = await responderAvanzado(
      pregunta: pregunta,
      historial: historial,
      imagenes: imagenes,
      audios: audios,
      usarInternet: usarInternet,
      modo: modo,
      rol: rol,
    );
    return response.respuesta;
  }

  Future<AiAssistantResponse> responderAvanzado({
    required String pregunta,
    required List<Map<String, String>> historial,
    List<String> imagenes = const <String>[],
    List<String> audios = const <String>[],
    bool usarInternet = true,
    String modo = 'asistente',
    String rol = 'usuario',
  }) async {
    final question = pregunta.trim();
    if (question.isEmpty || question.length > 2500) {
      throw const AiAssistantException(
        'Escribe una pregunta de hasta 2500 caracteres.',
      );
    }

    try {
      return await _firebaseResponse(
        question: question,
        historial: historial,
        imagenes: imagenes,
        audios: audios,
        usarInternet: usarInternet,
        modo: modo,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        throw const AiAssistantException(
          'Tu sesión expiró. Vuelve a iniciar sesión para usar la inteligencia artificial.',
        );
      }
      if (error.code == 'permission-denied') {
        throw const AiAssistantException(
          'Tu cuenta no tiene acceso a esa información privada.',
        );
      }
      return _onlineSmartResponse(
        question: question,
        historial: historial,
        rol: rol,
      );
    } on AiAssistantException {
      rethrow;
    } catch (_) {
      return _onlineSmartResponse(
        question: question,
        historial: historial,
        rol: rol,
      );
    }
  }

  Future<AiAssistantResponse> _firebaseResponse({
    required String question,
    required List<Map<String, String>> historial,
    required List<String> imagenes,
    required List<String> audios,
    required bool usarInternet,
    required String modo,
  }) async {
    final callable = _functions.httpsCallable(
      'saunaAssistantV2',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 28)),
    );
    final result = await callable.call(<String, dynamic>{
      'pregunta': question,
      'historial': historial
          .skip(historial.length > 10 ? historial.length - 10 : 0)
          .toList(growable: false),
      'imagenes': imagenes.take(4).toList(growable: false),
      'audios': audios.take(2).toList(growable: false),
      'usarInternet': usarInternet,
      'modo': modo == 'guia' ? 'guia' : 'asistente',
    });
    final raw = result.data;
    if (raw is! Map) {
      throw const AiAssistantException('La IA no devolvió una respuesta válida.');
    }
    final data = Map<String, dynamic>.from(raw);
    final answer = data['respuesta']?.toString().trim() ?? '';
    if (answer.isEmpty) {
      throw const AiAssistantException('La IA no devolvió una respuesta.');
    }
    final rawSources = data['fuentes'];
    final sources = rawSources is List
        ? rawSources
            .whereType<Map>()
            .map((item) => AiAssistantSource.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((source) => source.url.isNotEmpty)
            .toList(growable: false)
        : const <AiAssistantSource>[];
    return AiAssistantResponse(
      respuesta: answer,
      modelo: data['modelo']?.toString() ?? 'Sauna IA',
      usoInternet: data['usoInternet'] == true,
      fuentes: sources,
    );
  }

  Future<AiAssistantResponse> _onlineSmartResponse({
    required String question,
    required List<Map<String, String>> historial,
    required String rol,
  }) async {
    try {
      final messages = historial
          .skip(historial.length > 8 ? historial.length - 8 : 0)
          .map((message) => <String, String>{
                'role': (message['role'] == 'assistant' || message['rol'] == 'asistente') ? 'assistant' : 'user',
                'content': (message['content'] ?? message['texto'])?.toString() ?? '',
              })
          .where((message) => message['content']!.trim().isNotEmpty)
          .toList(growable: true);
      messages.add(<String, String>{'role': 'user', 'content': question});

      final response = await http
          .post(
            _onlineSmartEndpoint,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'workspace': 'sauna-stilo',
              'role': rol,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AiAssistantException(
          'Online Smart está temporalmente ocupada. Intenta nuevamente.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const AiAssistantException(
          'Online Smart no devolvió una respuesta válida.',
        );
      }
      final answer = decoded['text']?.toString().trim() ?? '';
      if (answer.isEmpty) {
        throw const AiAssistantException(
          'Online Smart no devolvió una respuesta. Intenta nuevamente.',
        );
      }
      return AiAssistantResponse(
        respuesta: answer,
        modelo: decoded['identity']?.toString() ?? 'Online Smart · Sauna Stilo',
        usoInternet: decoded['usoInternet'] == true,
        fuentes: const <AiAssistantSource>[],
      );
    } on AiAssistantException {
      rethrow;
    } catch (_) {
      throw const AiAssistantException(
        'No pude conectar con Online Smart. Revisa Internet e intenta nuevamente.',
      );
    }
  }
}
