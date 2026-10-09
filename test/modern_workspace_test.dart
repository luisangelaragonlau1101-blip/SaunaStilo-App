import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/presentation/modern_workspace.dart';
import 'package:saunastilo/widgets/stilo_orbit.dart';

const destinations = [
  NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
  NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Comunidad'),
  NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Mensajes'),
  NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Tareas'),
  NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
];

void main() {
  testWidgets(
    'mobile and desktop navigation share actions and preserve work when resizing',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final work = GlobalKey();
      var selected = 0;
      Widget app() => MaterialApp(
        home: ModernWorkspaceFrame(
          selectedIndex: selected,
          destinations: destinations,
          onSelected: (i) => selected = i,
          child: Padding(
            key: work,
            padding: const EdgeInsets.all(24),
            child: const TextField(
              decoration: InputDecoration(labelText: 'Descripción'),
            ),
          ),
        ),
      );
      await t.pumpWidget(app());
      expect(find.byType(StiloDock), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Trabajo sin perder');
      await t.tap(find.byIcon(Icons.assignment_outlined));
      await t.pump();
      expect(selected, 3);
      t.view.physicalSize = const Size(1440, 960);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.byType(StiloDock), findsNothing);
      expect(find.text('Trabajo sin perder'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('modern-tab-2')));
      expect(selected, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'work sections remain reachable at large text sizes and narrow widths',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 740);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var selected = -1;
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: WorkspaceTabs(
                items: const {
                  0: 'Del día',
                  1: 'Extras',
                  2: 'Actividades',
                  3: 'Proyectos',
                  4: 'Instalaciones y envíos',
                },
                selected: 0,
                onSelected: (i) => selected = i,
              ),
            ),
          ),
        ),
      );
      await t.ensureVisible(find.text('Instalaciones y envíos'));
      await t.pumpAndSettle();
      await t.tap(find.text('Instalaciones y envíos'));
      expect(selected, 4);
      expect(t.takeException(), isNull);
    },
  );
}
