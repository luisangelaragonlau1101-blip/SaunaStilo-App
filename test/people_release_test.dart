import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/team_profile_helpers.dart';
import 'package:saunastilo/widgets/team_profile_details.dart';
void main() {
  UserModel user(String role) => UserModel(id: 'worker', nombre: 'Prueba', correo: 'test@example.invalid', rol: role, fechaRegistro: DateTime(2026));
  test('birthday today stays today and past dates move to next year', () {
    expect(nextTeamBirthday(DateTime(2000,9,5),DateTime(2026,9,5,20)),DateTime(2026,9,5));
    expect(nextTeamBirthday(DateTime(2000,1,11),DateTime(2026,9,5)),DateTime(2027,1,11));
  });
  test('February 29 is observed on February 28 in a non-leap year', () {
    expect(nextTeamBirthday(DateTime(2000,2,29),DateTime(2027,1,1)),DateTime(2027,2,28));
    expect(nextTeamBirthday(DateTime(2000,2,29),DateTime(2028,1,1)),DateTime(2028,2,29));
  });
  test('Mexico date and optional interests have deterministic fallbacks', () {
    expect(mexicoToday(DateTime.utc(2026,9,6,2)),DateTime(2026,9,5));
    expect(profileTags(null),isEmpty);
    expect(profileTags(' carpintería, , música '),['carpintería','música']);
  });
  test('all roles can reach people and loans, workers reach justifications', () {
    for (final role in ['admin','maestro','trabajador','almacenista']) {
      final ids = AppActionCatalog.forUser(user(role)).map((a)=>a.id).toList();
      expect(ids,containsAll(['equipo','prestamos','cumpleanos','insignias']));
      expect(ids.contains('justificar'),role!='admin');
      expect(ids.contains('alerta_general'),role=='admin');
      expect(ids.toSet().length,ids.length);
    }
  });
  testWidgets('manual awards are not editable by a worker at phone width', (tester) async {
    tester.view.physicalSize=const Size(375,812); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:SingleChildScrollView(child:TeamProfileDetails(usuarioActual:user('trabajador'),perfilId:'worker',data:const {'intereses':'Música, Carpintería','coloresFavoritos':'Verde'})))));
    expect(find.byTooltip('Editar mis gustos'),findsOneWidget);
    expect(find.byTooltip('Agregar'),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('admin sees independent award and installation actions', (tester) async {
    await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),home:Scaffold(body:SingleChildScrollView(child:TeamProfileDetails(usuarioActual:user('admin'),perfilId:'other',data:const {})))));
    expect(find.byTooltip('Agregar'),findsNWidgets(2));
    expect(tester.takeException(),isNull);
  });
}
