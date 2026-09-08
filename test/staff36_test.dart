import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/screens/extra_work_screen.dart';
import 'package:saunastilo/screens/engineering_screen.dart';
import 'package:saunastilo/screens/admin_inbox_screen.dart';
import 'package:saunastilo/screens/personal_day_screen.dart';
import 'package:saunastilo/workflow/staff_policy.dart';

UserModel person(String role, {bool engineer = false}) => UserModel(id: 'qa', nombre: 'Persona QA', correo: 'qa@example.invalid', rol: role, fechaRegistro: DateTime(2026), panelIngenieria: engineer);
class ExtraFake extends CompanyLearningService {
  final bool fail;
  final calls = <String>[];
  ExtraFake({this.fail = false});
  @override Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> data = const {}]) async {
    calls.add(action);
    if (fail) throw StateError('No hay conexión.');
    if (action == 'personal-list') return {'items': [{'id': 'a', 'date': '2026-09-07', 'kind': 'task', 'title': 'Tarea recibida', 'details': '', 'quantity': '', 'time': '', 'done': false, 'createdBy': 'qa', 'createdByName': 'Persona QA', 'lastBy': 'Admin', 'steps': []}], 'history': []};
    if (action == 'personal-upcoming') return {'items': [], 'history': [], 'through': '2026-10-31'};
    return {'saved': true, 'items': []};
  }
}
void main() {
  test('recipients never become assigners based on a name or an engineering panel', () {
    expect(canAssignWork('trabajador'), false); expect(canAssignWork('almacenista'), false);
    expect(canAssignWork('admin'), true); expect(canAssignWork('maestro'), true);
    expect(canAssignWork('Ángel Zaldívar'), false);
  });
  test('project progress is derived from all assigned task states and does not invent empty completion', () {
    expect(projectCompletion([]), 0); expect(projectCompletion(['completado', 'pendiente', 'en_proceso', 'completado']), 50);
    expect(projectCompletion(['completado']), 100);
  });
  test('spoken and visible answers remove markup without losing technical values or the final sentence', () {
    expect(plainAssistantText('## Ayuda\n**Revisa** el modelo.\n- Lee [manual](https://example.invalid).'), 'Ayuda\nRevisa el modelo.\n• Lee manual.');
    final answer = '## Guía\n${List.filled(70, 'Conserva 220 V y 3.5 m sin inventar valores. ').join()}Esta es la última frase.';
    final parts = spokenAnswerChunks(answer, limit: 200);
    expect(parts.length, greaterThan(5)); expect(parts.every((s) => s.length <= 200), true);
    expect(parts.join(' '), endsWith('Esta es la última frase.')); expect(parts.join(' '), contains('220 V')); expect(parts.join(' '), isNot(contains('##')));
  });
  test('administrative and engineering actions remain scoped', () {
    for (final role in ['admin', 'maestro', 'almacenista', 'trabajador']) {
      final ids = AppActionCatalog.forUser(person(role)).map((a) => a.id).toList();
      expect(ids, containsAll(['trabajo_extra', 'estado_notificaciones', 'tareas', 'idiomas']));
      expect(ids.contains('bandeja_admin'), role == 'admin');
      expect(ids.contains('ingenieria'), role == 'admin');
      expect(ids.toSet().length, ids.length);
    }
    expect(AppActionCatalog.forUser(person('trabajador', engineer: true)).map((a) => a.id), contains('ingenieria'));
  });
  testWidgets('an unprivileged account cannot render administration or engineering controls', (t) async {
    await t.pumpWidget(MaterialApp(home: AdminInboxScreen(user: person('trabajador'))));
    expect(find.text('Solo Administración.'), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: EngineeringAccessControl(administrator: person('trabajador'), profileId: 'other', profile: const {}))));
    expect(find.byType(SwitchListTile), findsNothing);
  });
  testWidgets('personal recipients have checkmarks and extra reporting, never own-item edit or new shopping tasks', (t) async {
    await t.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: PersonalDayScreen(user: person('trabajador'), service: ExtraFake())));
    await t.pumpAndSettle();
    expect(find.byTooltip('Agregar Pendientes'), findsNothing); expect(find.byTooltip('Agregar Comidas'), findsNothing); expect(find.text('Editar'), findsNothing);
    expect(find.byKey(const ValueKey('personal-check-a')), findsOneWidget);
  });
  testWidgets('extra report form retains inputs and requires explicit confirmation on a small screen', (t) async {
    t.view.physicalSize = const Size(375, 900); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final service = ExtraFake(fail: true);
    await t.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: ExtraWorkForm(date: DateTime(2026, 9, 7), service: service)));
    final send = find.text('Enviar para revisión'); await t.ensureVisible(send); await t.pumpAndSettle(); await t.tap(send); await t.pumpAndSettle();
    expect(service.calls, isEmpty);
    final fields = find.byType(TextField); await t.ensureVisible(fields.at(0)); await t.enterText(fields.at(0), 'Apoyo adicional');
    await t.ensureVisible(fields.at(1)); await t.enterText(fields.at(1), 'Organicé las piezas sobrantes del proyecto.');
    final check = find.byType(CheckboxListTile); await t.ensureVisible(check); await t.pumpAndSettle(); await t.tap(check); await t.pumpAndSettle();
    await t.ensureVisible(send); await t.pumpAndSettle(); await t.tap(send); await t.pumpAndSettle();
    expect(service.calls, ['extra-create']); expect(find.text('No hay conexión.'), findsOneWidget);
    expect(t.widget<TextField>(fields.at(0)).controller!.text, 'Apoyo adicional'); expect(t.takeException(), isNull);
  });
}
