import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/widgets/authenticated_workspace_gate.dart';
import 'package:saunastilo/widgets/deferred_workspace.dart';
import 'package:saunastilo/widgets/enterprise_pending_summary.dart';
import 'package:saunastilo/widgets/workday_home.dart';

UserModel person(String id, [String role = 'trabajador']) => UserModel(
  id: id,
  nombre: 'Persona de prueba',
  correo: '$id@example.invalid',
  rol: role,
  fechaRegistro: DateTime(2026),
);
WorkspaceAccess access(
  String id, {
  bool cached = false,
  bool active = true,
  String role = 'trabajador',
  UserModel? override,
}) => WorkspaceAccess(
  userId: id,
  user: override ?? person(id, role),
  cached: cached,
  active: active,
);

void main() {
  testWidgets(
    'cached roles wait for the server; the current profile opens without a minimum intro',
    (t) async {
      final stream = StreamController<WorkspaceAccess>();
      addTearDown(stream.close);
      await t.pumpWidget(
        MaterialApp(
          home: AuthenticatedWorkspaceGate(
            userId: 'one',
            access: stream.stream,
            workspace: (_, u) => Text('Private ${u.rol}'),
            onRetry: () {},
            onLogout: () {},
          ),
        ),
      );
      stream.add(access('one', cached: true, role: 'admin'));
      await t.pump();
      expect(find.text('Private admin'), findsNothing);
      expect(find.text('Mis actividades de hoy'), findsOneWidget);
      stream.add(access('one'));
      await t.pump();
      expect(find.text('Private trabajador'), findsOneWidget);
      expect(find.byType(WorkspaceLoadingScreen), findsNothing);
      // No pump(Duration(...)), timer, or fade is necessary to use the workspace.
    },
  );

  testWidgets('a cached update cannot elevate the last server-validated role', (
    t,
  ) async {
    final stream = StreamController<WorkspaceAccess>();
    addTearDown(stream.close);
    await t.pumpWidget(
      MaterialApp(
        home: AuthenticatedWorkspaceGate(
          userId: 'one',
          access: stream.stream,
          workspace: (_, u) => Text('Access ${u.rol}'),
          onRetry: () {},
          onLogout: () {},
        ),
      ),
    );
    stream.add(access('one'));
    await t.pump();
    stream.add(access('one', cached: true, role: 'admin'));
    await t.pump();
    expect(find.text('Access trabajador'), findsOneWidget);
    expect(find.text('Access admin'), findsNothing);
    expect(find.textContaining('Sincronizando'), findsOneWidget);
  });

  testWidgets(
    'deactivation and permission errors remove the private workspace immediately',
    (t) async {
      final stream = StreamController<WorkspaceAccess>();
      addTearDown(stream.close);
      await t.pumpWidget(
        MaterialApp(
          home: AuthenticatedWorkspaceGate(
            userId: 'one',
            access: stream.stream,
            workspace: (_, u) => const Text('Private data'),
            onRetry: () {},
            onLogout: () {},
          ),
        ),
      );
      stream.add(access('one'));
      await t.pump();
      expect(find.text('Private data'), findsOneWidget);
      stream.add(access('one', active: false));
      await t.pump();
      expect(find.text('Private data'), findsNothing);
      expect(find.textContaining('desactivada'), findsOneWidget);
      stream.add(access('one'));
      await t.pump();
      stream.addError(StateError('permission-denied'));
      await t.pump();
      expect(find.text('Private data'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      stream.add(access('one', cached: true));
      await t.pump();
      expect(find.text('Private data'), findsNothing);
    },
  );

  testWidgets(
    'changing the account never reuses the other profile or queued response',
    (t) async {
      final first = StreamController<WorkspaceAccess>(),
          next = StreamController<WorkspaceAccess>();
      addTearDown(first.close);
      addTearDown(next.close);
      Widget app(String id, Stream<WorkspaceAccess> stream) => MaterialApp(
        home: AuthenticatedWorkspaceGate(
          userId: id,
          access: stream,
          workspace: (_, u) => Text('Profile ${u.id}'),
          onRetry: () {},
          onLogout: () {},
        ),
      );
      await t.pumpWidget(app('one', first.stream));
      first.add(access('one'));
      await t.pump();
      await t.pumpWidget(app('two', next.stream));
      expect(find.text('Profile one'), findsNothing);
      first.add(access('one', role: 'admin'));
      await t.pump();
      next.add(access('one'));
      await t.pump();
      expect(find.text('Profile one'), findsNothing);
      next.add(access('two', cached: true));
      await t.pump();
      expect(find.text('Profile two'), findsNothing);
      next.add(access('two'));
      await t.pump();
      expect(find.text('Profile two'), findsOneWidget);
    },
  );

  testWidgets(
    'retrying a stream never flashes its previous successful snapshot',
    (t) async {
      final first = StreamController<WorkspaceAccess>(),
          second = StreamController<WorkspaceAccess>();
      addTearDown(first.close);
      addTearDown(second.close);
      Widget app(Stream<WorkspaceAccess> stream) => MaterialApp(
        home: AuthenticatedWorkspaceGate(
          userId: 'one',
          access: stream,
          workspace: (_, u) => const Text('Private workspace'),
          onRetry: () {},
          onLogout: () {},
        ),
      );
      await t.pumpWidget(app(first.stream));
      first.add(access('one'));
      await t.pump();
      await t.pumpWidget(app(second.stream));
      expect(find.text('Private workspace'), findsNothing);
      second.add(access('one', cached: true));
      await t.pump();
      expect(find.text('Private workspace'), findsNothing);
    },
  );

  testWidgets('the worker can act while a secondary section is still loading', (
    t,
  ) async {
    final secondary = Completer<void>();
    var delivered = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkdayHome(
            header: const Text('STILO'),
            journey: const Text('MI JORNADA'),
            activities: FilledButton(
              onPressed: () => delivered = true,
              child: const Text('TERMINAR'),
            ),
            installations: const SizedBox.shrink(),
            weekly: FutureBuilder<void>(
              future: secondary.future,
              builder: (_, s) => s.connectionState == ConnectionState.done
                  ? const Text('Mi avance')
                  : const LinearProgressIndicator(),
            ),
            options: const Text('Todas mis opciones'),
          ),
        ),
      ),
    );
    await t.tap(find.text('TERMINAR'));
    await t.pump();
    expect(delivered, isTrue);
    expect(secondary.isCompleted, isFalse);
    expect(t.takeException(), isNull);
    secondary.complete();
    await t.pump();
  });

  testWidgets(
    'administrative secondary counts are requested only when expanded',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnterprisePendingSummary(
              user: person('admin', 'admin'),
              load: () async {
                calls++;
                return {'facturasPendientes': 3, 'comprasPendientes': 2};
              },
            ),
          ),
        ),
      );
      await t.pump();
      expect(calls, 0);
      await t.tap(find.text('Mi empresa'));
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text('3 facturas pendientes · 2 compras por autorizar'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an optional module can fail and retry without blocking navigation',
    (t) async {
      var attempts = 0;
      await t.pumpWidget(
        MaterialApp(
          home: DeferredWorkspace(
            load: () async {
              if (++attempts == 1) throw StateError('offline');
            },
            builder: (_) => const Scaffold(body: Text('Module ready')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(find.text('Module ready'), findsOneWidget);
      expect(attempts, 2);
    },
  );
}
