import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/screens/daily_tasks_screen.dart';
import 'package:saunastilo/services/company_learning_service.dart';

UserModel person(String role) => UserModel(id: role, nombre: role, correo: '$role@example.invalid', rol: role, fechaRegistro: DateTime(2026));
class DailyFake extends CompanyLearningService {
  final calls = <String>[];
  bool fail = false;
  final task = <String, dynamic>{'taskId': 'task', 'day': '20260928', 'title': 'Ordenar taller', 'details': 'Adjuntar fotos del trabajo.', 'userId': 'trabajador', 'userName': 'Trabajador', 'createdBy': 'maestro', 'createdByName': 'Maestro', 'status': 'en_progreso', 'evidenceCount': 1, 'evidence': [{'name': 'foto.jpg', 'contentType': 'image/jpeg', 'url': 'https://example.invalid/isolated.jpg'}], 'history': []};
  @override Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}]) async {
    calls.add(action);
    if (fail) throw StateError('No se confirmó el guardado.');
    if (action == 'daily-list') return {'items': [{...task}]};
    if (action == 'daily-complete') task['status'] = 'completado';
    return {'task': {...task}, 'saved': true};
  }
}
void main() {
  testWidgets('all profiles see daily tasks while only administrators and masters can assign', (t) async {
    for (final role in ['admin', 'maestro', 'trabajador', 'almacenista']) {
      await t.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: DailyTasksScreen(key: ValueKey(role), user: person(role), service: DailyFake())));
      await t.pumpAndSettle();
      expect(find.text('Ordenar taller'), findsOneWidget);
      expect(find.text('Asignar tarea'), ['admin', 'maestro'].contains(role) ? findsOneWidget : findsNothing);
    }
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });
  testWidgets('recipient can deliver with evidence; an error keeps the assignment open and retryable', (t) async {
    final api = DailyFake();
    await t.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: DailyTaskDetail(user: person('trabajador'), task: api.task, service: api)));
    await t.pumpAndSettle();
    expect(find.text('foto.jpg'), findsOneWidget);
    final submit = find.text('Entregar tarea terminada'); await t.ensureVisible(submit); await t.pumpAndSettle();
    api.fail = true; await t.tap(submit); await t.pumpAndSettle();
    expect(api.task['status'], 'en_progreso'); expect(find.text('No se confirmó el guardado.'), findsOneWidget);
    api.fail = false; await t.ensureVisible(submit); await t.tap(submit); await t.pumpAndSettle();
    expect(api.task['status'], 'completado'); expect(find.text('Entregar tarea terminada'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('a master reviewing another person sees evidence without recipient delivery controls', (t) async {
    final api = DailyFake();
    await t.pumpWidget(MaterialApp(home: DailyTaskDetail(user: person('maestro'), task: api.task, service: api)));
    await t.pumpAndSettle();
    expect(find.text('foto.jpg'), findsOneWidget); expect(find.text('Adjuntar foto o PDF'), findsNothing); expect(find.text('Entregar tarea terminada'), findsNothing);
  });
}
