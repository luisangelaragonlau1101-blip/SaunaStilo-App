import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/workflow/productivity_2026.dart';
import 'package:saunastilo/presentation/appearance.dart';
import 'package:saunastilo/widgets/seasonal_decoration.dart';

WorkActivity activity(
  String id,
  DateTime day, {
  String status = 'completado',
}) => WorkActivity(
  id: id,
  assignees: const ['a', 'b'],
  assignedDay: day,
  approvedDay: status == 'completado' ? day : null,
  status: status,
);

void main() {
  test(
    'shared work is counted once globally and once in each responsible persons own progress',
    () {
      final shared = activity('shared', DateTime(2026, 11, 23));
      for (final person in [null, 'a', 'b']) {
        final report = WorkProductivity.fromActivities(
          [shared, shared],
          today: DateTime(2026, 11, 25),
          personId: person,
        );
        expect(report.approvedWeek, 1);
        expect(report.uniqueActivities, 1);
      }
      final legacy = WorkActivity.fromMap({
        'id': 'legacy',
        'estatus': 'completado',
        'asignadoATrabajadorId': 'a',
      });
      expect(legacy.approved, isFalse);
      expect(legacy.status, 'en_revision');
    },
  );

  test(
    'streaks skip rest, approved leave and days without assignments, but corrections on a past workday interrupt them',
    () {
      final rows = [
        activity('friday', DateTime(2026, 11, 20)),
        activity('monday', DateTime(2026, 11, 23)),
        activity('leave', DateTime(2026, 11, 24), status: 'pendiente'),
        activity('today', DateTime(2026, 11, 26), status: 'pendiente'),
      ];
      final schedule = WorkSchedule(
        approvedLeaveDays: {DateTime(2026, 11, 24)},
      );
      final report = WorkProductivity.fromActivities(
        rows,
        today: DateTime(2026, 11, 26),
        schedule: schedule,
      );
      expect(report.currentStreak, 2);
      expect(report.bestStreak, 2);
      final interrupted = WorkProductivity.fromActivities(
        [
          ...rows,
          activity(
            'correction',
            DateTime(2026, 11, 25),
            status: 'cambios_solicitados',
          ),
        ],
        today: DateTime(2026, 11, 26),
        schedule: schedule,
      );
      expect(interrupted.currentStreak, 0);
    },
  );

  test(
    'season selection uses an explicitly configured company anniversary',
    () {
      expect(stiloSeason(DateTime(2026, 12, 15)), StiloSeason.winter);
      expect(stiloSeason(DateTime(2027, 1, 1)), StiloSeason.newYear);
      expect(stiloSeason(DateTime(2026, 11, 25)), isNull);
      expect(
        stiloSeason(
          DateTime(2026, 11, 25),
          anniversary: DateTime(2000, 11, 25),
        ),
        StiloSeason.anniversary,
      );
    },
  );

  testWidgets(
    'seasonal decoration respects reduced motion, never intercepts controls and pauses in background',
    (t) async {
      final settings = AppearanceController()..seasonalEffects = true;
      var taps = 0;
      Widget app(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: SeasonalDecoration(
            controller: settings,
            date: DateTime(2026, 12, 15),
            child: Scaffold(
              body: TextButton(
                onPressed: () => taps++,
                child: const Text('Entregar'),
              ),
            ),
          ),
        ),
      );
      await t.pumpWidget(app(true));
      expect(find.byKey(const ValueKey('seasonal-decoration')), findsNothing);
      await t.pumpWidget(app(false));
      expect(find.byKey(const ValueKey('seasonal-decoration')), findsOneWidget);
      await t.tap(find.text('Entregar'));
      expect(taps, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(find.byKey(const ValueKey('seasonal-decoration')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(find.byKey(const ValueKey('seasonal-decoration')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );
}
