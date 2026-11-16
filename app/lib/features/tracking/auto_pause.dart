import 'dart:math' as math;

import 'package:gps_pipeline/gps_pipeline.dart';

enum AutoPauseChange { none, paused, resumed }

/// Decides when a recording should pause itself because the runner stopped
/// (traffic lights, tying a shoe) and resume when they move again.
///
/// Deliberately conservative: a wrong pause loses time, a missed pause only
/// leaves a few idle seconds in. It pauses only when the Doppler speed is
/// below a walking shuffle *and* the position has not drifted, for
/// [stillFor]; so a phone that reports no speed at all never pauses a moving
/// runner. Fixes with poor accuracy are ignored.
class AutoPauseDetector {
  AutoPauseDetector(this.profile);

  final ActivityProfile profile;

  static const Duration stillFor = Duration(seconds: 8);
  static const double maxAccuracyM = 30;

  /// Further than this from where "standing still" began means the runner is
  /// in fact moving (slowly, or without Doppler speed).
  static const double driftM = 12;

  /// Moving this far from the pause point resumes even without a speed.
  static const double resumeDistanceM = 20;

  /// Driving and indoor / poor-signal recordings never auto-pause.
  static bool supports(ActivityProfile p) =>
      p != ActivityProfile.drive && p != ActivityProfile.indoorPoor;

  double get pauseBelowMps => switch (profile) {
        ActivityProfile.walk || ActivityProfile.hike => 0.3,
        ActivityProfile.cycle => 0.8,
        _ => 0.5,
      };

  double get resumeAboveMps => switch (profile) {
        ActivityProfile.walk || ActivityProfile.hike => 0.7,
        ActivityProfile.cycle => 1.8,
        _ => 1.0,
      };

  bool _paused = false;
  bool get isPaused => _paused;

  DateTime? _stillSince;
  double _anchorLat = 0;
  double _anchorLng = 0;
  int _movingStreak = 0;

  /// How long the runner had already been standing when the pause began, so
  /// the caller can take it back off the clock.
  Duration lastStillDuration = Duration.zero;

  void reset() {
    _paused = false;
    _stillSince = null;
    _movingStreak = 0;
    lastStillDuration = Duration.zero;
  }

  AutoPauseChange update({
    required double lat,
    required double lng,
    required double speedMps,
    required double accuracyM,
    required DateTime timestamp,
  }) {
    if (!supports(profile)) return AutoPauseChange.none;
    if (!(accuracyM <= maxAccuracyM)) return AutoPauseChange.none;

    if (_paused) {
      _movingStreak = speedMps >= resumeAboveMps ? _movingStreak + 1 : 0;
      final moved = _distanceM(_anchorLat, _anchorLng, lat, lng);
      if (_movingStreak >= 2 || moved > resumeDistanceM) {
        reset();
        return AutoPauseChange.resumed;
      }
      return AutoPauseChange.none;
    }

    if (speedMps >= pauseBelowMps) {
      _stillSince = null;
      return AutoPauseChange.none;
    }
    final since = _stillSince;
    if (since == null ||
        timestamp.isBefore(since) ||
        _distanceM(_anchorLat, _anchorLng, lat, lng) > driftM) {
      _stillSince = timestamp;
      _anchorLat = lat;
      _anchorLng = lng;
      return AutoPauseChange.none;
    }
    final still = timestamp.difference(since);
    if (still >= stillFor) {
      _paused = true;
      _movingStreak = 0;
      lastStillDuration = still;
      return AutoPauseChange.paused;
    }
    return AutoPauseChange.none;
  }

  /// Short-range distance in metres (equirectangular; plenty at these scales).
  static double _distanceM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final x = (lng2 - lng1) * math.pi / 180 * math.cos((lat1 + lat2) / 2 * math.pi / 180);
    final y = (lat2 - lat1) * math.pi / 180;
    return math.sqrt(x * x + y * y) * r;
  }
}
