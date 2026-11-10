import 'coordinate_util.dart';
import 'models.dart';

/// The single rule for turning pipeline output into drawable lines and a
/// distance figure. The live map, the saved activity route, GPX export and the
/// distance total all go through here, so what you see while running, what is
/// saved, and the kilometres you're credited with can never disagree.
///
/// Why segments exist: previously every accepted point was joined into one
/// polyline. After a pause (or a long signal dropout) the next point was joined
/// to the last one with a straight line — across buildings, rivers, wherever —
/// which is exactly the "shows I went places I didn't go" artifact. Strava,
/// Apple Fitness and NRC all break the line at a pause instead.
class TrackSegments {
  const TrackSegments._();

  /// A gap shorter than this (straight-line) is bridged — a few seconds under a
  /// bridge or tree cover. Anything longer breaks the line rather than invent
  /// a path the runner may not have taken.
  static const double maxBridgeM = 50.0;

  /// True if [curr] must start a new line instead of joining [prev].
  static bool startsNewSegment(PipelineResult prev, PipelineResult curr) {
    switch (curr.filterStatus) {
      case FilterStatus.gapLong:
        return true;
      case FilterStatus.gapShort:
        return chordM(prev, curr) > maxBridgeM;
      default:
        return false;
    }
  }

  /// True if the hop from the previous point to [curr] counts toward distance
  /// (assuming they are in the same segment). Stationary centroids don't add
  /// distance — standing at a crossing must not tick the odometer.
  static bool countsDistance(PipelineResult curr) =>
      curr.filterStatus == FilterStatus.filtered ||
      curr.filterStatus == FilterStatus.gapShort;

  static double chordM(PipelineResult a, PipelineResult b) =>
      CoordinateUtil.haversineMetres(
        a.smoothedLat ?? a.raw.lat,
        a.smoothedLng ?? a.raw.lng,
        b.smoothedLat ?? b.raw.lat,
        b.smoothedLng ?? b.raw.lng,
      );

  /// Accepted results grouped into continuous segments (each ≥ 1 point).
  static List<List<PipelineResult>> split(Iterable<PipelineResult> results) {
    final out = <List<PipelineResult>>[];
    PipelineResult? prev;
    for (final r in results) {
      if (!r.isAccepted) continue;
      if (prev == null || startsNewSegment(prev, r)) {
        out.add([r]);
      } else {
        out.last.add(r);
      }
      prev = r;
    }
    return out;
  }

  /// Total distance in metres, never counting the jump between segments.
  /// See [DistanceAccumulator] for how each step is measured.
  static double distanceM(
    Iterable<PipelineResult> results, {
    double maxSpeedMps = double.infinity,
  }) {
    final acc = DistanceAccumulator(maxSpeedMps: maxSpeedMps);
    for (final seg in split(results)) {
      for (var i = 0; i < seg.length; i++) {
        acc.add(seg[i], newSegment: i == 0);
      }
    }
    return acc.totalM;
  }
}

/// Measures distance the way Apple Watch / Garmin do: primarily by
/// integrating the device's Doppler speed over time, which is accurate to a
/// few cm/s and immune to the sideways wobble of GPS positions. Summing
/// point-to-point hops instead adds every sideways wiggle to the total — on
/// the test tracks that overstated distance by ~30–50 %.
///
/// When a fix has no speed (negative [RawFix.speedMps], common on Wi-Fi /
/// cell assisted fixes) the last speed reading is carried for up to
/// [speedHoldS]. Beyond that, or across a signal gap, it falls back to the
/// straight-line hop from the last counted point — counted only once the hop
/// exceeds the fix's own uncertainty (clamped to [fallbackThresholdM] ..
/// [fallbackMaxM]), so position noise can't tick the odometer while the real
/// displacement is still inside the noise.
///
/// Feed it every accepted result in order (live or when reprocessing);
/// [add] returns the distance added by that point.
class DistanceAccumulator {
  final double maxSpeedMps;
  final double fallbackThresholdM;
  final double fallbackMaxM;

  /// How long (s) the last speed reading may stand in for missing ones.
  static const double speedHoldS = 3.0;

  /// Longest step (s) over which a speed reading is trusted; longer steps
  /// (signal gaps) use the position fallback.
  static const double maxSpeedStepS = 5.0;

  double totalM = 0;
  PipelineResult? _prev;
  PipelineResult? _anchor;
  double? _lastSpeed;
  DateTime? _lastSpeedAt;

  DistanceAccumulator({
    this.maxSpeedMps = double.infinity,
    this.fallbackThresholdM = 8.0,
    this.fallbackMaxM = 15.0,
  });

  double add(PipelineResult r, {required bool newSegment}) {
    if (!r.isAccepted) return 0;
    final prev = _prev;
    _prev = r;
    if (newSegment || prev == null || _anchor == null) {
      _anchor = r;
      return 0;
    }
    if (!TrackSegments.countsDistance(r)) return 0;

    double d = 0;
    final t = r.raw.timestamp;
    final dt = t.difference(prev.raw.timestamp).inMilliseconds / 1000.0;
    final stepOk = r.filterStatus == FilterStatus.filtered && dt > 0 && dt <= maxSpeedStepS;
    final v = r.raw.speedMps;
    final hasSpeed = v >= 0 && v <= maxSpeedMps;
    final held = !hasSpeed &&
        _lastSpeed != null &&
        _lastSpeedAt != null &&
        t.difference(_lastSpeedAt!).inMilliseconds / 1000.0 <= speedHoldS;

    if (stepOk && hasSpeed) {
      // Trapezoid when the previous point also had a usable speed.
      final pv = prev.raw.speedMps;
      final avg = (pv >= 0 && pv <= maxSpeedMps) ? (pv + v) / 2 : v;
      d = avg * dt;
      _anchor = r;
    } else if (stepOk && held) {
      d = _lastSpeed! * dt;
      _anchor = r;
    } else {
      final threshold =
          r.raw.accuracy.toDouble().clamp(fallbackThresholdM, fallbackMaxM);
      final hop = TrackSegments.chordM(_anchor!, r);
      if (hop >= threshold) {
        d = hop;
        _anchor = r;
      }
    }
    if (hasSpeed) {
      _lastSpeed = v;
      _lastSpeedAt = t;
    }
    totalM += d;
    return d;
  }

  void reset() {
    totalM = 0;
    _prev = null;
    _anchor = null;
    _lastSpeed = null;
    _lastSpeedAt = null;
  }
}
