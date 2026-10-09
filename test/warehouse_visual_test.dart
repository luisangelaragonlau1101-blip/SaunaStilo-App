import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/presentation/appearance.dart';
import 'package:saunastilo/screens/warehouse_workspace_screen.dart';
import 'package:saunastilo/widgets/soft_workspace.dart';

void main() {
  for (final role in [
    AppRoles.admin,
    AppRoles.almacenista,
    AppRoles.trabajador,
  ]) {
    testWidgets('warehouse keeps $role actions reachable with large text', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 740);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final user = UserModel(
        id: 'visual',
        nombre: 'Equipo',
        correo: 'visual@example.invalid',
        rol: role,
        fechaRegistro: DateTime(2026),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: stiloTheme(stiloPalettes.first),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: WarehouseWorkspaceScreen(user: user),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(StiloSectionHero), findsOneWidget);
      await t.scrollUntilVisible(find.text('Productos y existencias'), 180);
      await t.pumpAndSettle();
      expect(find.text('Productos y existencias'), findsOneWidget);
      final manager = role != AppRoles.trabajador;
      if (manager) {
        await t.scrollUntilVisible(find.text('Entregas y devoluciones'), 180);
        await t.pumpAndSettle();
        expect(
          find.text('Entregas y devoluciones').hitTestable(),
          findsOneWidget,
        );
      }
      final menu =
          (t.widget<ListView>(find.byType(ListView)).childrenDelegate
                  as SliverChildListDelegate)
              .children
              .whereType<StiloActionRow>();
      expect(menu.length, manager ? 5 : 4);
      final box = find.text(manager ? 'Cajitas del equipo' : 'Mi cajita');
      await t.scrollUntilVisible(box, 180);
      await t.pumpAndSettle();
      expect(box.hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
