import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/widgets/task_action_bar.dart';
import 'package:saunastilo/widgets/project_closure_panel.dart';

void main() {
  testWidgets(
    'task controls expose delivery to owner and admin, approval only to admin',
    (t) async {
      var completed = 0, approved = 0;
      for (final admin in [false, true]) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskActionBar(
                status: 'pendiente',
                admin: admin,
                responsible: !admin,
                onComplete: () => completed++,
                onApprove: () => approved++,
              ),
            ),
          ),
        );
        await t.tap(find.text('Marcar como terminada'));
        await t.pump();
        expect(find.text('Aprobar y finalizar'), findsNothing);
      }
      expect(completed, 2);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskActionBar(
              status: 'en_revision',
              admin: false,
              responsible: true,
              onComplete: () => completed++,
              onApprove: () => approved++,
            ),
          ),
        ),
      );
      expect(find.text('Aprobar y finalizar'), findsNothing);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskActionBar(
              status: 'en_revision',
              admin: true,
              responsible: false,
              onComplete: () => completed++,
              onApprove: () => approved++,
            ),
          ),
        ),
      );
      await t.tap(find.text('Aprobar y finalizar'));
      expect(approved, 1);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskActionBar(
              status: 'pendiente',
              admin: false,
              responsible: false,
              onComplete: () => completed++,
              onApprove: () => approved++,
            ),
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets(
    'project controls stay visible on mobile, assigned staff deliver and admin closes',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var deliveries = 0, approvals = 0;
      for (final admin in [false, true]) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ProjectClosureActions(
                  admin: admin,
                  assigned: !admin,
                  closed: false,
                  delivered: false,
                  onComplete: () => deliveries++,
                  onApprove: () => approvals++,
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Marcar proyecto como terminado'));
        await t.pump();
        expect(
          find.text('Aprobar y finalizar proyecto'),
          admin ? findsOneWidget : findsNothing,
        );
        if (admin) await t.tap(find.text('Aprobar y finalizar proyecto'));
        expect(t.takeException(), isNull);
      }
      expect(deliveries, 2);
      expect(approvals, 1);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectClosureActions(
              admin: true,
              assigned: false,
              closed: true,
              delivered: true,
              onComplete: () => deliveries++,
              onApprove: () => approvals++,
            ),
          ),
        ),
      );
      expect(find.text('Proyecto aprobado y finalizado'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );
}
