import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/widgets/quick_task_actions.dart';

class TaskApi extends CompanyLearningService {
  Map<String, dynamic> task = {
    'taskId': 'shared',
    'status': 'pendiente',
    'title': 'Actividad compartida',
    'userId': 'primary',
    'userIds': ['primary', 'worker'],
    'requiresEvidence': true,
    'evidenceCount': 0,
    'evidence': [],
  };
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add({'action': action, ...data});
    if (action == 'daily-read') return {'task': task};
    return {'saved': true, 'task': task};
  }
}

UserModel user(String id, String role) => UserModel(
  id: id,
  nombre: id,
  correo: '$id@example.invalid',
  rol: role,
  fechaRegistro: DateTime(2026),
);
void main() {
  testWidgets(
    'a secondary shared assignee can start but cannot approve the activity',
    (t) async {
      final api = TaskApi();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickTaskActions(
              task: api.task,
              user: user('worker', 'trabajador'),
              service: api,
              onChanged: () async {},
              onDetails: () {},
            ),
          ),
        ),
      );
      expect(find.text('INICIAR'), findsOneWidget);
      expect(find.text('APROBAR'), findsNothing);
      await t.tap(find.text('INICIAR'));
      await t.pumpAndSettle();
      expect(api.calls.single['action'], 'daily-start');
    },
  );
  testWidgets(
    'admin submits a correction with the current delivery and dialog closes safely',
    (t) async {
      final api = TaskApi();
      api.task = {
        ...api.task,
        'status': 'en_revision',
        'submissionId': 'delivery',
        'submittedAt': '2026-11-25T18:00:00Z',
      };
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickTaskActions(
              task: api.task,
              user: user('admin', 'admin'),
              service: api,
              onChanged: () async {},
              onDetails: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Solicitar corrección'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Ajusta el acabado');
      await t.tap(find.text('Enviar corrección'));
      await t.pumpAndSettle();
      final call = api.calls.singleWhere((c) => c['action'] == 'daily-review');
      expect(call['decision'], 'changes');
      expect(call['comment'], 'Ajusta el acabado');
      expect(call['submittedAt'], api.task['submittedAt']);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'cancelling the camera cannot submit a task with required evidence',
    (t) async {
      final api = TaskApi();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickTaskActions(
              task: api.task,
              user: user('worker', 'trabajador'),
              service: api,
              onChanged: () async {},
              onDetails: () {},
              capturePhoto: () async => null,
            ),
          ),
        ),
      );
      await t.tap(find.text('TERMINAR'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('ENTREGAR'));
      await t.tap(find.text('ENTREGAR'));
      await t.pumpAndSettle();
      expect(api.calls.any((c) => c['action'] == 'daily-complete'), isFalse);
      expect(
        find.text('Esta actividad necesita una foto antes de entregar.'),
        findsOneWidget,
      );
    },
  );
}
