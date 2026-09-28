import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/presentation/appearance.dart';
import 'package:saunastilo/services/admin_workspace_service.dart';
import 'package:saunastilo/services/app_action_catalog.dart';
import 'package:saunastilo/widgets/personal_header.dart';
import 'package:saunastilo/screens/human_resources_screen.dart';
import 'package:saunastilo/screens/business_workspace_screen.dart';

UserModel member(String role, {bool engineering = false, DateTime? birthday}) => UserModel(id: 'test', nombre: 'Persona QA', correo: 'qa@example.invalid', rol: role, fechaRegistro: DateTime(2026), panelIngenieria: engineering, cumpleanos: birthday);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('appearance survives reload and never crosses accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppearanceController();
    await prefs.bindUser('one'); await prefs.save(paletteId: 'rosa', festive: false, simple: true);
    await prefs.bindUser('two'); expect(prefs.palette.id, 'stilo'); expect(prefs.celebrations, true);
    await prefs.save(paletteId: 'blanco');
    final reload = AppearanceController(); await reload.bindUser('one');
    expect(reload.palette.id, 'rosa'); expect(reload.celebrations, false); expect(reload.compact, true);
    await reload.bindUser(null); expect(reload.palette.id, 'stilo');
    prefs.dispose(); reload.dispose();
  });
  test('one work and warehouse entry; HR and engineering remain scoped', () {
    for (final role in ['admin','maestro','almacenista','trabajador']) {
      final actions = AppActionCatalog.mainMenu(member(role)).map((a) => a.id).toList();
      expect(actions.where((a) => a == 'tareas').length, 1); expect(actions.where((a) => a == 'inventario').length, 1);
      for (final old in ['proyectos','almacen_movimientos','solicitudes_almacen','cajitas','cajita','prestamos','asistencias','plan_personal']) { expect(actions, isNot(contains(old))); }
      expect(actions.contains('gestion'), role == 'admin'); expect(actions, isNot(contains('ingenieria')));
    }
    expect(AppActionCatalog.mainMenu(member('trabajador', engineering: true)).map((a) => a.id), contains('ingenieria'));
  });
  test('birthday takes precedence; leap day and festival windows are explicit', () {
    expect(celebrationFor(DateTime(2026,9,16), DateTime(2001,9,16)), contains('cumpleaños'));
    expect(celebrationFor(DateTime(2026,2,28), DateTime(2000,2,29)), contains('cumpleaños'));
    expect(celebrationFor(DateTime(2026,9,16), null), contains('México'));
    expect(celebrationFor(DateTime(2026,9,28), null), isNull);
  });
  test('financial amounts use exact cents and reject ambiguous or invalid entries', () {
    expect(moneyInCents('123.45'), 12345); expect(moneyInCents('12,5'), 1250);
    for (final input in ['1,234.50','-5','0','NaN','1.999','1000000000']) { expect(moneyInCents(input), isNull); }
  });
  testWidgets('private spaces refuse non-admins before Firebase access', (tester) async {
    for (final role in ['trabajador','maestro','almacenista']) {
      await tester.pumpWidget(MaterialApp(home: HumanResourcesScreen(user: member(role))));
      expect(find.text('Este espacio es exclusivo de Administración.'), findsOneWidget);
      await tester.pumpWidget(MaterialApp(home: BusinessWorkspaceScreen(user: member(role))));
      expect(find.text('Este espacio es exclusivo de Administración.'), findsOneWidget);
    }
  });
  testWidgets('all palettes keep main header readable at phone width and large text', (tester) async {
    tester.view.physicalSize = const Size(390,844); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    for (final palette in stiloPalettes) {
      final theme = stiloTheme(palette);
      final light = theme.colorScheme.onSurface.computeLuminance(), dark = theme.scaffoldBackgroundColor.computeLuminance();
      final contrast = (light > dark ? light + .05 : dark + .05) / (light > dark ? dark + .05 : light + .05);
      expect(contrast, greaterThan(4.5));
      await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.3)), child: PersonalHeader(user: member('trabajador'))))));
      expect(find.text('Hola, Persona'), findsOneWidget); expect(find.byTooltip('Personalizar mi panel'), findsOneWidget); expect(tester.takeException(), isNull);
    }
  });
  testWidgets('celebration toggle refreshes the existing header without a color change', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppearanceController.instance;
    await tester.runAsync(() => settings.bindUser('birthday-test'));
    final today = DateTime.now().toUtc().subtract(const Duration(hours: 6));
    final person = member('trabajador', birthday: DateTime(2000, today.month, today.day));
    await tester.pumpWidget(MaterialApp(theme: stiloTheme(settings.palette), home: Scaffold(body: PersonalHeader(user: person))));
    expect(find.textContaining('Feliz cumpleaños'), findsOneWidget);
    await tester.runAsync(() => settings.save(festive: false)); await tester.pump();
    expect(find.textContaining('Feliz cumpleaños'), findsNothing);
    await tester.runAsync(() => settings.save(festive: true)); await tester.pump();
    expect(find.textContaining('Feliz cumpleaños'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => settings.bindUser(null));
  }, timeout: const Timeout(Duration(seconds: 45)));
}
