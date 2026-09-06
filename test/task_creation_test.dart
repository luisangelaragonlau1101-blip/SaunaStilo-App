import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/actividad_model.dart';
import 'package:saunastilo/widgets/task_creation_choice.dart';
import 'package:saunastilo/widgets/warehouse_header.dart';

void main() {
  testWidgets('admin creates a general task without querying or having a project', (tester) async {
    var general = 0, project = 0;
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: TaskCreationChoice(admin: true, onGeneral: () => general++, onProject: () => project++))));
    await tester.tap(find.text('Tarea general'));
    expect(general, 1); expect(project, 0); expect(tester.takeException(), isNull);
  });
  testWidgets('master keeps project-scoped choices instead of granting global assignments', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TaskCreationChoice(admin: false, onGeneral: () {}, onProject: () {}))));
    expect(find.text('Tarea general'), findsNothing); expect(find.text('Tarea de un proyecto'), findsOneWidget);
  });
  test('general task survives model roundtrip and keeps its responsible person', () {
    final task = ActividadModel(id: 'daily', proyectoId: '', titulo: 'Preparar el taller', descripcion: 'Subir evidencia', asignadoATrabajadorId: 'worker', fechaInicio: DateTime(2026, 9, 6), fechaTermino: DateTime(2026, 9, 7));
    final restored = ActividadModel.fromJson(task.toJson(), task.id);
    expect(restored.proyectoId, isEmpty); expect(restored.asignadoATrabajadorId, 'worker'); expect(restored.requiereEvidencia, true);
  });
  testWidgets('warehouse header fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.5)), child: Scaffold(body: SingleChildScrollView(child: WarehouseHeader(title: 'Cada herramienta, bajo control.', subtitle: 'Solicitudes, entradas, salidas e historial', compact: true))))));
    expect(tester.takeException(), isNull);
  });
}
