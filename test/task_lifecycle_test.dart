import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/workflow/task_lifecycle.dart';

void main() {
  test('legacy completion is a delivery until explicit approval', () {
    for (final status in ['completado', 'completada', 'completed', 'finalizado', 'terminada']) {
      expect(taskStatus(status), 'en_revision');
      expect(taskStatus(status, approved: true), 'completado');
    }
    expect(taskStatus('en proceso'), 'en_progreso');
    expect(taskStatus(null), 'pendiente');
  });
  test('multi-day work and older pending tasks remain visible on Home', () {
    expect(taskFallsOnDay('20261001', '20261008', '20261007'), isTrue);
    expect(taskFallsOnDay('20261001', '20261002', '20261007'), isFalse);
    expect(taskFallsOnDay('20261001', '20261002', '20261007', carryPending: true), isTrue);
    expect(taskFallsOnDay('20261001', '20261002', '20261007', carryPending: true, approved: true), isFalse);
    expect(taskFallsOnDay('20261009', '20261010', '20261007', carryPending: true), isFalse);
    expect(taskFallsOnDay('20260901', '20261008', '202609'), isTrue);
    expect(taskFallsOnDay('20260901', '20261008', '202610'), isFalse);
  });
}
