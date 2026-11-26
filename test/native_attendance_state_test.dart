import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/services/native_attendance_watch.dart';

void main() {
  test(
    'GPS policy permits an explicit record action without claiming manual permission',
    () {
      final state = nativeAttendanceReceipt(
        userId: 'worker',
        day: '20261125',
        profile: {'rol': 'trabajador', 'activo': true},
        record: {},
      );
      expect(state['supportsRecording'], isTrue);
      expect(state['supportsManual'], isFalse);
      expect(state['requiresLocation'], isTrue);
    },
  );
  test(
    'device-only legacy hours stay separate from server-confirmed attendance',
    () {
      final state = nativeAttendanceReceipt(
        userId: 'worker',
        day: '20261125',
        profile: {'rol': 'trabajador'},
        record: {},
        legacy: {'horaEntrada': '2026-11-25T15:00:00Z'},
        cached: true,
      );
      expect(state['legacyPending'], isTrue);
      expect((state['data'] as Map).containsKey('horaEntrada'), isFalse);
      expect(state['cached'], isTrue);
    },
  );
  test('inactive and read-only profiles do not enable attendance buttons', () {
    for (final own in [false, true]) {
      final state = nativeAttendanceReceipt(
        userId: 'worker',
        day: '20261125',
        profile: {
          'rol': 'trabajador',
          'activo': false,
          'asistenciaManualPermitida': true,
        },
        record: {},
        own: own,
      );
      expect(state['supportsRecording'], isFalse);
      expect(state['supportsManual'], isFalse);
    }
  });
}
