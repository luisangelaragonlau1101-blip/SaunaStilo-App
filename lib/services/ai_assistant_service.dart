import 'package:cloud_functions/cloud_functions.dart';

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

  final FirebaseFunctions _functions;

  Future<String> responder({
    required String pregunta,
    required List<Map<String, String>> historial,
    List<String> imagenes = const <String>[],
    List<String> audios = const <String>[],
    bool usarInternet = true,
    String modo = 'asistente',
  }) async {
    final response = await responderAvanzado(
      pregunta: pregunta,
      historial: historial,
      imagenes: imagenes,
      audios: audios,
      usarInternet: usarInternet,
      modo: modo,
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
  }) async {
    final question = pregunta.trim();
    if (question.isEmpty || question.length > 2500) {
      throw const AiAssistantException(
        'Escribe una pregunta de hasta 2500 caracteres.',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'saunaAssistantV2',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 70),
        ),
      );
      final result = await callable.call(<String, dynamic>{
        'pregunta': question,
        'historial': historial.skip(historial.length > 10 ? historial.length - 10 : 0).toList(growable: false),
        'imagenes': imagenes.take(4).toList(growable: false),
        'audios': audios.take(2).toList(growable: false),
        'usarInternet': usarInternet,
        'modo': modo == 'guia' ? 'guia' : 'asistente',
      });
      final raw = result.data;
      if (raw is! Map) {
        throw const AiAssistantException(
          'La IA no devolvió una respuesta válida.',
        );
      }
      final data = Map<String, dynamic>.from(raw);
      final answer = data['respuesta']?.toString().trim() ?? '';
      if (answer.isEmpty) {
        throw const AiAssistantException(
          'La IA no devolvió una respuesta. Intenta de nuevo; no se ha realizado ninguna acción.',
        );
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
        modelo: data['modelo']?.toString() ?? '',
        usoInternet: data['usoInternet'] == true,
        fuentes: sources,
      );
    } on FirebaseFunctionsException catch (error) {
      final message = switch (error.code) {
        'unauthenticated' =>
          'Tu sesión expiró. Vuelve a iniciar sesión para usar Sauna IA.',
        'permission-denied' =>
          'Tu cuenta no tiene acceso a esa información o servicio.',
        'not-found' =>
          'La nueva Sauna IA todavía no está publicada en Firebase.',
        'failed-precondition' =>
          'Falta configurar el servicio de IA en Firebase/Google Cloud. Administración debe revisar el motor y sus permisos.',
        'resource-exhausted' =>
          'Se alcanzó el límite temporal de uso de IA. Intenta de nuevo más tarde.',
        'deadline-exceeded' =>
          'La IA tardó demasiado. Revisa la conexión y vuelve a intentarlo.',
        'invalid-argument' =>
          'No se pudo procesar la pregunta o el adjunto. Revisa su tamaño y formato.',
        _ =>
          'No se pudo conectar con Sauna IA. Revisa la conexión; si persiste, administración debe verificar el servicio publicado.',
      };
      throw AiAssistantException(message);
    } on AiAssistantException {
      rethrow;
    } catch (_) {
      throw const AiAssistantException(
        'No se pudo conectar con Sauna IA. No se generó ninguna respuesta simulada.',
      );
    }
  }
}
