import 'dart:developer' as developer;

import 'startup_metrics_stub.dart'
    if (dart.library.js_interop) 'startup_metrics_web.dart'
    as platform;

/// Anonymous milestones. No identity, task, or company data is recorded.
class StartupMetrics {
  static void mark(String milestone) {
    developer.Timeline.instantSync('stilo:$milestone');
    platform.mark('stilo:$milestone');
  }
}
