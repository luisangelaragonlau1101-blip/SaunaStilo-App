import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/widgets/global_assistant_layer.dart';

void main() {
  testWidgets('assistant bubble remains available on pushed pages and offers audio', (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: navigator,
      builder: (_, child) => GlobalAssistantLayer(navigatorKey: navigator,
        userId: 'worker', child: child!),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Otra página')))),
        child: const Text('Abrir otra página'))))));
    await t.pumpAndSettle();
    await t.tap(find.text('Abrir otra página')); await t.pumpAndSettle();
    expect(find.text('Otra página'), findsOneWidget);
    final bubble = find.byType(FloatingActionButton);
    expect(bubble, findsOneWidget);
    await t.drag(bubble, const Offset(-300, -60)); await t.pumpAndSettle();
    await t.tap(bubble); await t.pumpAndSettle();
    expect(find.text('Online Smart'), findsOneWidget);
    expect(find.byTooltip('Grabar audio'), findsOneWidget);
    expect(find.byTooltip('Enviar pregunta'), findsOneWidget);
    await t.tap(find.byTooltip('Cerrar asistente')); await t.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('assistant is hidden before login', (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: navigator,
      builder: (_, child) => GlobalAssistantLayer(navigatorKey: navigator, child: child!),
      home: const Scaffold(body: Text('Iniciar sesión'))));
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
