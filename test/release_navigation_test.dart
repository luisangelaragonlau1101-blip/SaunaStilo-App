import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/local_guide.dart';

UserModel user(String role) => UserModel(id: 'test-user', nombre: 'Prueba', correo: 'example@example.test', rol: role, fechaRegistro: DateTime(2026));
void main() {
  test('Every supported role keeps the primary modules without duplicate IDs', () {
    for (final role in ['admin','almacenista','maestro','trabajador']) {
      final ids = AppActionCatalog.forUser(user(role)).map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['ia', 'guia', 'mensajes', 'configuracion']));
    }
  });
  test('Private commercial modules and voice studio remain admin-only', () {
    for (final role in ['almacenista','maestro','trabajador']) {
      final ids=AppActionCatalog.forUser(user(role)).map((a)=>a.id);
      for(final id in ['voz','clientes','cotizaciones','ventas']) {expect(ids, isNot(contains(id)));}
    }
    expect(AppActionCatalog.forUser(user('admin')).map((a)=>a.id),containsAll(['voz','clientes','cotizaciones','ventas']));
  });
  test('Search handles accents, case and more than one word', () {
    final actions=AppActionCatalog.forUser(user('admin'));
    expect(actions.where((a)=>a.matches('GUIA')).single.id,'guia');
    expect(actions.where((a)=>a.matches('mi voz')).single.id,'voz');
    expect(actions.where((a)=>a.matches('configuracion')).single.id,'configuracion');
  });
  test('Included guide explains operation without querying live data', () {
    expect(LocalGuide.answer('¿Cómo registro mi jornada?', 'trabajador'), contains('Asistencia'));
    expect(LocalGuide.answer('¿Cómo grabo mi voz?', 'trabajador'), contains('Solo Administración'));
    expect(LocalGuide.answer('¿Cómo grabo mi voz?', 'admin'), contains('Estudio de voz'));
    expect(LocalGuide.answer('¿Cuántos clientes tenemos?', 'admin'), isNull);
    expect(LocalGuide.answer('Busca en Internet información actual', 'admin'), isNull);
  });
}
