import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/screens/online_smart_screen.dart';
import 'package:saunastilo/screens/jornada_screen.dart';
void main() {
  UserModel user(String role) => UserModel(id:'test', nombre:'Prueba', correo:'test@example.invalid', rol:role, fechaRegistro:DateTime(2026));
  test('all roles keep searchable tasks, community, messages and profile', () {
    for(final role in ['admin','maestro','trabajador','almacenista']) {
      final items=AppActionCatalog.forUser(user(role));
      for(final id in ['tareas','comunidad','mensajes','perfil']) expect(items.any((a)=>a.id==id),isTrue);
      expect(items.where((a)=>a.id=='tareas').single.matches('actividades'),isTrue);
      expect(items.any((a)=>a.id=='alerta_general'),role=='admin');
    }
  });
  test('user-facing service screens preserve required account', () {
    final model=user('trabajador');
    expect(OnlineSmartScreen(usuario:model).usuario.id,'test');
    expect(JornadaScreen(usuario:model).usuario.id,'test');
  });
}
