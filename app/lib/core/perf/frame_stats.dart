import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in frame-timing probe for performance work. Off by default; enable
/// with `--dart-define=MWENDO_FRAME_STATS=true` (use a profile or release
/// build — debug-mode timings are meaningless).
///
/// Every [_window] frames it logs one line to the console / logcat:
///   `MWENDO_FRAMES n=120 build avg/p90/max=… raster avg/p90/max=… janky=…`
/// where "janky" counts frames whose build or raster phase exceeded the
/// 16.7 ms budget of a 60 Hz display.
class FrameStats {
  static const bool enabled = bool.fromEnvironment('MWENDO_FRAME_STATS');
  static const int _window = 120;
  static const double _budgetMs = 1000 / 60;

  static final List<double> _build = [];
  static final List<double> _raster = [];

  static void install() {
    if (!enabled) return;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _build.add(t.buildDuration.inMicroseconds / 1000);
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
    if (_build.length < _window) return;
    String stats(List<double> v) {
      final s = [...v]..sort();
      final avg = s.reduce((a, b) => a + b) / s.length;
      final p90 = s[(s.length * 0.9).floor().clamp(0, s.length - 1)];
      return '${avg.toStringAsFixed(1)}/${p90.toStringAsFixed(1)}/${s.last.toStringAsFixed(1)}';
    }

    var janky = 0;
    for (var i = 0; i < _build.length; i++) {
      if (math.max(_build[i], _raster[i]) > _budgetMs) janky++;
    }
    debugPrint('MWENDO_FRAMES n=${_build.length} build avg/p90/max=${stats(_build)}ms '
        'raster avg/p90/max=${stats(_raster)}ms janky=$janky');
    _build.clear();
    _raster.clear();
  }
}
