import 'package:cloud_functions/cloud_functions.dart';

class BirthdayPreferencesService {
  final FirebaseFunctions? functions;
  BirthdayPreferencesService({this.functions});
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await (functions ?? FirebaseFunctions.instance)
        .httpsCallable('enterprisePreferences')
        .call<Object?>({'action': action, ...data});
    if (result.data is! Map)
      throw StateError('No se pudo consultar la privacidad del cumpleaños.');
    return Map<String, dynamic>.from(result.data as Map);
  }
}
