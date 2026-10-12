import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/proyecto_model.dart';
import 'package:saunastilo/widgets/project_picker.dart';

// Isolated query fake: no Firebase SDK calls or production account.
// ignore: subtype_of_sealed_class
class ProjectQueryFake implements Query<Map<String, dynamic>> {
  final _subscriptions = <bool>[];
  int get subscriptions => _subscriptions.length;
  final bool recover;
  ProjectQueryFake({this.recover = false});
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _subscriptions.add(true);
    if (recover && subscriptions > 1)
      return Stream.value(ProjectSnapshotFake());
    return Stream.error(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProjectSnapshotFake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    ProjectDocumentFake(),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// This fake only supplies the server document values read by Proyecto.
// ignore: subtype_of_sealed_class
class ProjectDocumentFake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'assigned-project';
  @override
  Map<String, dynamic> data() => {
    'titulo': 'Proyecto asignado',
    'encargados': ['maestro', 'trabajador'],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'retry opens a new query and returns the selected project after recovery',
    (t) async {
      final query = ProjectQueryFake(recover: true);
      Proyecto? chosen;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  chosen = await showModalBottomSheet<Proyecto>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ProjectPickerSheet(
                      query: query,
                      titulo: 'Proyecto para la nueva tarea',
                      admin: false,
                    ),
                  );
                },
                child: const Text('Asignar'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Asignar'));
      await t.pumpAndSettle();
      expect(find.textContaining('El servidor bloqueó'), findsOneWidget);
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(query.subscriptions, 2);
      expect(find.textContaining('El servidor bloqueó'), findsNothing);
      await t.tap(find.text('Proyecto asignado'));
      await t.pumpAndSettle();
      expect(chosen?.id, 'assigned-project');
      expect(chosen?.encargados, ['maestro', 'trabajador']);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'permission recovery stays reachable on a narrow phone with enlarged text',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 640);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final query = ProjectQueryFake();
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: ProjectPickerSheet(
                query: query,
                titulo: 'Proyecto para la nueva tarea',
                admin: false,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Reintentar'), 160);
      await t.pumpAndSettle();
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(query.subscriptions, 2);
      expect(t.takeException(), isNull);
    },
  );
}
