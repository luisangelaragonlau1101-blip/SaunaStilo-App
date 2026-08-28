import 'package:cloud_functions/cloud_functions.dart';

class AiAssistantService {
  AiAssistantService()
      : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String?> responder({
    required String pregunta,
    required List<Map<String, String>> historial,
    List<String> imagenes = const <String>[],
  }) async {
    final callable = _functions.httpsCallable(
      'saunaAssistant',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 12)),
    );
    final result = await callable.call(<String, dynamic>{
      'pregunta': pregunta,
      'historial': historial.take(6).toList(growable: false),
      'imagenes': imagenes.take(4).toList(growable: false),
    });
    final raw = result.data;
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final respuesta = data['respuesta']?.toString().trim();
    return respuesta == null || respuesta.isEmpty ? null : respuesta;
  }
}
