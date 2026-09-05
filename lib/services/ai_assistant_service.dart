import 'package:cloud_functions/cloud_functions.dart';

class AiAssistantException implements Exception {
  final String message;
  const AiAssistantException(this.message);
  @override
  String toString() => message;
}

class AiAssistantService {
  AiAssistantService() : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseFunctions _functions;

  Future<String> responder({
    required String pregunta,
    required List<Map<String, String>> historial,
    List<String> imagenes = const <String>[],
    List<String> audios = const <String>[],
  }) async {
    final question = pregunta.trim();
    if (question.isEmpty || question.length > 2500) {
      throw const AiAssistantException('Escribe una pregunta de hasta 2500 caracteres.');
    }
    try {
      final callable = _functions.httpsCallable('saunaAssistant',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 70)));
      final result = await callable.call(<String, dynamic>{
        'pregunta': question,
        'historial': historial.skip(historial.length > 10 ? historial.length - 10 : 0).toList(growable: false),
        'imagenes': imagenes.take(4).toList(growable: false),
        'audios': audios.take(2).toList(growable: false),
      });
      final data = result.data;
      final answer = data is Map ? data['respuesta']?.toString().trim() : null;
      if (answer == null || answer.isEmpty) {
        throw const AiAssistantException('La IA no devolvió una respuesta. Intenta de nuevo; no se ha realizado ninguna acción.');
      }
      return answer;
    } on FirebaseFunctionsException catch (error) {
      final message = switch (error.code) {
        'unauthenticated' => 'Tu sesión expiró. Vuelve a iniciar sesión para usar Sauna IA.',
        'permission-denied' => 'Tu cuenta no tiene acceso a este servicio. Consulta a administración.',
        'not-found' => 'El servicio Sauna IA todavía no está publicado en Firebase.',
        'failed-precondition' => 'Falta configurar el servicio de IA en Firebase/Google Cloud. Administración debe revisar el motor y sus permisos.',
        'resource-exhausted' => 'Se alcanzó el límite temporal de uso de IA. Intenta de nuevo más tarde.',
        'deadline-exceeded' => 'La IA tardó demasiado. Revisa la conexión y vuelve a intentarlo.',
        'invalid-argument' => 'No se pudo procesar la pregunta o el adjunto. Revisa su tamaño y formato.',
        _ => 'No se pudo conectar con Sauna IA. Revisa la conexión; si persiste, administración debe verificar el servicio publicado.',
      };
      throw AiAssistantException(message);
    } on AiAssistantException { rethrow; }
    catch (_) {
      throw const AiAssistantException('No se pudo conectar con Sauna IA. Tu mensaje no se convirtió en una respuesta automática simulada.');
    }
  }
}
