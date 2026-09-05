import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/screens/operations_shell.dart';
import 'package:saunastilo/widgets/jornada_compacta.dart';

void main() {
  test('essential tabs remain direct and include Home', () {
    expect(operationsDestinations.map((d) => d.label).toList(), ['Inicio','Proyectos','Comunidad','Chats','Perfil']);
  });
  test('Mexico workday does not change at UTC midnight', () {
    expect(mexicoDayKey(DateTime.parse('2026-09-08T03:00:00Z')), '20260907');
    expect(mexicoDayKey(DateTime.parse('2026-09-08T06:00:00Z')), '20260908');
  });
  testWidgets('navigation can switch at phone width without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375,667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) => Scaffold(body: Text('Tab $selected'), bottomNavigationBar: NavigationBar(selectedIndex: selected, destinations: operationsDestinations, onDestinationSelected: (index) => setState(() => selected = index))))));
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Tab 3'), findsOneWidget);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Tab 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
