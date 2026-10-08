import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/widgets/today_tasks_card.dart';

class HomeTasksFake extends CompanyLearningService {
  bool carried = false;
  @override Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> data = const {}]) async {
    carried = data['includePending'] == true;
    Map<String, dynamic> task(String title, String owner, String status) => {
      'taskId': title, 'day': '20260901', 'workKind': 'extra', 'title': title,
      'userId': owner, 'userName': owner, 'status': status, 'percentage': 40,
    };
    return {'items': [task('Pendiente anterior', 'worker', 'en_progreso'),
      task('Entrega del equipo', 'other', 'en_revision')]};
  }
}
UserModel user(String id, String role) => UserModel(id: id, nombre: id,
  correo: '$id@example.invalid', rol: role, fechaRegistro: DateTime(2026));

void main() {
  testWidgets('Home requests older pending work and shows only the recipient tasks', (t) async {
    final api = HomeTasksFake();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
      TodayTasksCard(user: user('worker', 'trabajador'), service: api),
    ]))));
    await t.pumpAndSettle();
    expect(api.carried, isTrue);
    expect(find.text('Pendiente anterior'), findsOneWidget);
    expect(find.text('Entrega del equipo'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Administration sees pending team approvals on Home', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
      TodayTasksCard(user: user('admin', 'admin'), service: HomeTasksFake()),
    ]))));
    await t.pumpAndSettle();
    expect(find.text('1 entregas por aprobar'), findsOneWidget);
    expect(find.text('Entrega del equipo'), findsOneWidget);
    expect(find.text('Pendiente anterior'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
