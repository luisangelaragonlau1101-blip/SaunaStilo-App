import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/screens/admin_team_progress_screen.dart';
import 'package:saunastilo/screens/daily_tasks_screen.dart';
import 'package:saunastilo/services/attendance_gateway_service.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/workflow/team_progress.dart';

UserModel _viewer(String role) => UserModel(
  id: role,
  nombre: 'Cuenta $role',
  correo: '$role@example.invalid',
  rol: role,
  fechaRegistro: DateTime(2026),
);

class _TeamProgressFake extends CompanyLearningService {
  final calls = <String>[];
  bool fail = false;
  late final List<Map<String, dynamic>> tasks = _fixtures();

  List<Map<String, dynamic>> _fixtures() {
    final today = AttendanceGatewayService.today;
    Map<String, dynamic> task({
      required String id,
      required String title,
      required String userId,
      required String name,
      required String status,
      required String kind,
      required int percentage,
      required DateTime day,
      required DateTime due,
      String projectId = '',
      DateTime? approved,
    }) => {
      'taskId': id,
      'title': title,
      'details': 'El trabajo se conserva con sus avances reales.',
      'userId': userId,
      'userName': name,
      'createdBy': 'admin',
      'createdByName': 'Administración',
      'projectId': projectId,
      'workKind': kind,
      'day': AttendanceGatewayService.dayKey(day),
      'dueDay': AttendanceGatewayService.dayKey(due),
      'dueAt': due.toUtc().toIso8601String(),
      'status': status,
      'percentage': percentage,
      'approvedAt': approved?.toUtc().toIso8601String(),
      'evidenceCount': 0,
      'evidence': <Map<String, dynamic>>[],
      'history': <Map<String, dynamic>>[],
    };
    return [
      task(
        id: 'pending-project',
        title: 'Fabricar marco del proyecto',
        userId: 'ana',
        name: 'Ana',
        status: 'pendiente',
        kind: 'proyecto',
        percentage: 0,
        day: today.subtract(const Duration(days: 2)),
        due: today.subtract(const Duration(days: 1)),
        projectId: 'cabina',
      ),
      {
        ...task(
          id: 'review-daily',
          title: 'Revisión eléctrica entregada',
          userId: 'luis',
          name: 'Luis',
          status: 'en_revision',
          kind: 'dia',
          percentage: 100,
          day: today,
          due: today.add(const Duration(days: 1)),
        ),
        'submissionId': 'submission-luis',
        'evidenceCount': 1,
        'evidence': [
          {
            'name': 'reporte-electricidad.pdf',
            'contentType': 'application/pdf',
            'url': 'https://example.invalid/reporte-electricidad.pdf',
          },
        ],
        'history': [
          {
            'comment': 'Cableado revisado y entrega registrada',
            'percentage': 100,
            'actorName': 'Luis',
            'at': today.toUtc().toIso8601String(),
          },
        ],
      },
      task(
        id: 'approved-extra',
        title: 'Inventario extra aprobado en el historial',
        userId: 'ana',
        name: 'Ana',
        status: 'completado',
        kind: 'extra',
        percentage: 100,
        day: today.subtract(const Duration(days: 45)),
        due: today.subtract(const Duration(days: 40)),
        approved: today.subtract(const Duration(days: 39)),
      ),
      task(
        id: 'progress-installation',
        title: 'Instalación en cliente',
        userId: 'marta',
        name: 'Marta',
        status: 'en_progreso',
        kind: 'instalacion',
        percentage: 55,
        day: today,
        due: today.add(const Duration(days: 2)),
        projectId: 'cabina',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    calls.add(action);
    if (fail) throw StateError('No se pudo consultar el avance del equipo.');
    if (action == 'daily-admin-overview') {
      return {
        'viewerId': 'admin',
        'items': tasks.map((task) => {...task}).toList(),
        'people': [
          {
            'id': 'ana',
            'name': 'Ana',
            'role': 'trabajador',
            'active': true,
            'department': 'Fabricación',
          },
          {
            'id': 'luis',
            'name': 'Luis',
            'role': 'maestro',
            'active': true,
            'department': 'Fabricación',
          },
          {
            'id': 'marta',
            'name': 'Marta',
            'role': 'trabajador',
            'active': true,
            'department': 'Instalaciones',
          },
          {
            'id': 'sin-tareas',
            'name': 'Persona sin asignaciones',
            'role': 'almacenista',
            'active': true,
            'department': 'Almacén',
          },
        ],
        'projects': [
          {
            'id': 'cabina',
            'title': 'Cabina principal',
            'status': 'en_progreso',
          },
        ],
      };
    }
    if (action == 'daily-read') {
      return {
        'task': {
          ...tasks.singleWhere((task) => task['taskId'] == body['taskId']),
        },
      };
    }
    throw StateError('Acción inesperada en la prueba: $action');
  }
}

Future<void> _show(
  WidgetTester tester,
  _TeamProgressFake api, {
  String role = 'admin',
  Size size = const Size(1280, 1000),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: AdminTeamProgressScreen(user: _viewer(role), service: api),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  final dropdown = find.byKey(ValueKey(key));
  if (key != 'team-person' && dropdown.evaluate().isEmpty) {
    final advanced = find.byKey(const ValueKey('team-filters'));
    await _reveal(tester, advanced);
    if (dropdown.evaluate().isEmpty) {
      await tester.tap(
        find.descendant(of: advanced, matching: find.text('Más filtros')),
      );
      await tester.pumpAndSettle();
    }
  }
  await _reveal(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    return;
  }
  final scrollable = find
      .descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: scrollable,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

Future<void> _status(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await _reveal(tester, chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'date filters keep earlier submissions awaiting administration while historical approvals stay in all dates',
    () {
      final today = AttendanceGatewayService.today;
      final old = {
        'day': AttendanceGatewayService.dayKey(
          today.subtract(const Duration(days: 45)),
        ),
        'dueAt': today
            .subtract(const Duration(days: 40))
            .toUtc()
            .toIso8601String(),
        'status': 'en_revision',
      };
      expect(teamTaskInPeriod(old, 'today', today: today), isTrue);
      expect(teamTaskOverdue(old), isFalse);
      final approved = {...old, 'status': 'completado'};
      expect(teamTaskInPeriod(approved, 'today', today: today), isFalse);
      expect(teamTaskInPeriod(approved, 'all', today: today), isTrue);
      expect(
        teamTaskInPeriod({'status': 'pendiente'}, 'today', today: today),
        isFalse,
      );
    },
  );

  testWidgets(
    'admin sees everyone including historical approvals; submitted work is awaiting approval',
    (tester) async {
      final api = _TeamProgressFake();
      await _show(tester, api);
      expect(api.calls, ['daily-admin-overview']);
      expect(find.text('4 tareas'), findsOneWidget);
      expect(find.text('1 por aprobar'), findsOneWidget);
      expect(find.text('1 aprobadas'), findsOneWidget);
      expect(find.text('1 vencidas'), findsOneWidget);
      expect(find.text('4 tareas en esta vista'), findsOneWidget);
      for (final title in [
        'Fabricar marco del proyecto',
        'Revisión eléctrica entregada',
        'Inventario extra aprobado en el historial',
        'Instalación en cliente',
      ]) {
        await _reveal(tester, find.text(title));
        expect(find.text(title), findsOneWidget);
      }
      await _status(tester, 'Aprobadas');
      expect(find.text('1 tareas en esta vista'), findsOneWidget);
      expect(
        find.text('Inventario extra aprobado en el historial'),
        findsOneWidget,
      );
      expect(find.text('Revisión eléctrica entregada'), findsNothing);
      await _status(tester, 'Por aprobar');
      expect(find.text('1 tareas en esta vista'), findsOneWidget);
      expect(find.text('Revisión eléctrica entregada'), findsOneWidget);
      expect(
        find.text('Inventario extra aprobado en el historial'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('person and status filters combine without mixing coworkers', (
    tester,
  ) async {
    final api = _TeamProgressFake();
    await _show(tester, api);
    await _select(tester, 'team-person', 'Ana');
    expect(find.text('2 tareas en esta vista'), findsOneWidget);
    expect(find.text('Revisión eléctrica entregada'), findsNothing);
    expect(find.text('Instalación en cliente'), findsNothing);
    await _status(tester, 'Aprobadas');
    expect(find.text('1 tareas en esta vista'), findsOneWidget);
    expect(
      find.text('Inventario extra aprobado en el historial'),
      findsOneWidget,
    );
    expect(find.text('Fabricar marco del proyecto'), findsNothing);
    await _status(tester, 'Vencidas');
    expect(find.text('Fabricar marco del proyecto'), findsOneWidget);
    expect(
      find.text('Inventario extra aprobado en el historial'),
      findsNothing,
    );
    await _select(tester, 'team-person', 'Persona sin asignaciones');
    expect(find.text('0 tareas en esta vista'), findsOneWidget);
    expect(find.byType(WorkTaskCard), findsNothing);
    expect(
      api.calls.where((action) => action == 'daily-admin-overview').length,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('department, project, work kind and today filters combine', (
    tester,
  ) async {
    final api = _TeamProgressFake();
    await _show(tester, api);
    await _select(tester, 'team-department', 'Instalaciones');
    await _select(tester, 'team-project', 'Cabina principal');
    await _select(tester, 'team-kind', 'Instalaciones');
    await _select(tester, 'team-period', 'Hoy');
    expect(find.text('1 tareas en esta vista'), findsOneWidget);
    expect(find.text('Instalación en cliente'), findsOneWidget);
    expect(find.text('Revisión eléctrica entregada'), findsNothing);
    expect(
      find.text('Inventario extra aprobado en el historial'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'non-administrator never requests or renders the company overview',
    (tester) async {
      for (final role in ['maestro', 'trabajador', 'almacenista']) {
        final api = _TeamProgressFake();
        await _show(tester, api, role: role);
        expect(api.calls, isEmpty);
        expect(find.byType(WorkTaskCard), findsNothing);
        expect(find.text('Fabricar marco del proyecto'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed overview is explicit and retry restores actual tasks', (
    tester,
  ) async {
    final api = _TeamProgressFake()..fail = true;
    await _show(tester, api);
    expect(
      find.text('No se pudo consultar el avance del equipo.'),
      findsOneWidget,
    );
    expect(find.byType(WorkTaskCard), findsNothing);
    api.fail = false;
    final retry = find.text('Reintentar');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(api.calls, ['daily-admin-overview', 'daily-admin-overview']);
    expect(
      find.text('No se pudo consultar el avance del equipo.'),
      findsNothing,
    );
    expect(find.text('4 tareas en esta vista'), findsOneWidget);
    expect(find.text('Revisión eléctrica entregada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh failure removes stale tasks and counters until retry', (
    tester,
  ) async {
    final api = _TeamProgressFake();
    await _show(tester, api);
    expect(find.text('4 tareas'), findsOneWidget);
    api.fail = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo consultar el avance del equipo.'),
      findsOneWidget,
    );
    expect(find.text('4 tareas'), findsNothing);
    expect(find.byType(WorkTaskCard), findsNothing);
    api.fail = false;
    final retry = find.text('Reintentar');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('4 tareas'), findsOneWidget);
    expect(api.calls.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing the account removes administration data immediately', (
    tester,
  ) async {
    final api = _TeamProgressFake();
    Widget app(String role) => MaterialApp(
      theme: ThemeData.dark(),
      home: AdminTeamProgressScreen(
        key: const ValueKey('shared-overview-state'),
        user: _viewer(role),
        service: api,
      ),
    );
    await tester.pumpWidget(app('admin'));
    await tester.pumpAndSettle();
    expect(find.text('4 tareas'), findsOneWidget);
    await tester.pumpWidget(app('maestro'));
    await tester.pumpAndSettle();
    expect(api.calls, ['daily-admin-overview']);
    expect(find.text('4 tareas'), findsNothing);
    expect(find.byType(WorkTaskCard), findsNothing);
    await tester.pumpWidget(app('admin'));
    await tester.pumpAndSettle();
    expect(api.calls, ['daily-admin-overview', 'daily-admin-overview']);
    expect(find.text('4 tareas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'per-person summary includes unassigned staff and opens their work',
    (tester) async {
      final api = _TeamProgressFake();
      await _show(tester, api);
      final panel = find.byKey(const ValueKey('team-people'));
      await tester.ensureVisible(panel);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por persona'));
      await tester.pumpAndSettle();
      final ana = find.ancestor(
        of: find.text('Ana').last,
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: ana,
          matching: find.text('1 de 2 aprobadas · 0 por aprobar · 1 vencidas'),
        ),
        findsOneWidget,
      );
      final unassigned = find.ancestor(
        of: find.text('Persona sin asignaciones').last,
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: unassigned,
          matching: find.text('Sin asignaciones en esta selección.'),
        ),
        findsOneWidget,
      );
      final open = find.descendant(
        of: ana,
        matching: find.text('Ver sus tareas'),
      );
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('2 tareas en esta vista'), findsOneWidget);
      expect(find.text('Revisión eléctrica entregada'), findsNothing);
      expect(find.text('Instalación en cliente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin opens a submitted task with its saved evidence and history',
    (tester) async {
      final api = _TeamProgressFake();
      await _show(tester, api);
      await _status(tester, 'Por aprobar');
      final title = find.text('Revisión eléctrica entregada');
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.byType(DailyTaskDetail), findsOneWidget);
      expect(api.calls.last, 'daily-read');
      expect(find.text('reporte-electricidad.pdf'), findsOneWidget);
      expect(find.text('Aprobar y finalizar'), findsOneWidget);
      expect(
        find.text('Cableado revisado y entrega registrada · 100 %'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('320-pixel phone and large text keep the overview usable', (
    tester,
  ) async {
    final api = _TeamProgressFake();
    await _show(tester, api, size: const Size(320, 800), textScale: 1.6);
    await _reveal(tester, find.text('4 tareas'));
    expect(find.text('4 tareas'), findsOneWidget);
    await _status(tester, 'Por aprobar');
    final title = find.text('Revisión eléctrica entregada');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    expect(title.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
