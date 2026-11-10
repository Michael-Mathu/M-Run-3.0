# gps_pipeline

A high-precision, pure Dart mathematical telemetry processing engine for running, cycling, and vehicular GPS traces.

## Features

- **Deterministic Pipeline** (updated 2026-11-09):
  1. `FixValidator`: Boundary checks, monotonic timestamps, and anti-mock filtering.
  - Warm-up gate: until the first point is accepted, fixes worse than 12 m are rejected (max 20 s) so coarse cell/Wi-Fi start fixes don't draw a "hook".
  2. `QualityGate`: Activity-specific accuracy radius thresholds and inverse-variance weighting.
  3. `OutlierDetector`: Implied-speed gating that subtracts each fix's accuracy radius first (10 m/s ceiling for runs), plus 3-point lookahead spike rejection.
  4. `KalmanFilter`: 2D local tangent plane (ENU) state-space filter with adaptive process noise and Mahalanobis innovation gating. Gated fixes are dropped (no dead-reckoned points); after 3 in a row it re-anchors on the measurement. Accuracy floor 3 m.
  5. `StationarySuppressor`: Density-weighted centroid clustering to eliminate drift during stops.
  6. `GapDetector`: Temporal gap identification and state demarcation.
  7. `TrackSegments` / `DistanceAccumulator`: one shared rule for where a track line breaks (gaps are never bridged with straight lines) and Doppler-speed distance with an accuracy-aware fallback.

  `MapMatcher` (OSRM road snapping) is still in the package but the app no longer calls it.
- **Diagnostics & Quality Metrics**: `SessionQualityReport` calculation (rejection rates, median/P95 accuracy, spikes per km, signal gaps).
- **Pure Dart**: Zero Flutter UI dependencies — runnable on servers, CLI tools, and mobile engines.

## Usage

```dart
import 'package:gps_pipeline/gps_pipeline.dart';

void main() {
  final pipeline = GpsPipeline(profile: ActivityProfile.run);

  // Real-time processing
  final fix = RawFix(
    lat: -1.2921,
    lng: 36.8219,
    elevation: 1680.0,
    timestamp: DateTime.now(),
    speedMps: 3.5, // use -1 when the device reports no speed
    accuracy: 8,
  );

  final result = pipeline.process(fix);
  if (result != null && result.isAccepted) {
    print('Smoothed Lat: ${result.smoothedLat}, Lng: ${result.smoothedLng}');
  }
}
```

### Distance and line segments

```dart
final results = GpsPipeline(profile: ActivityProfile.run).reprocess(fixes);
final segments = TrackSegments.split(results);           // one polyline each
final metres = TrackSegments.distanceM(results,
    maxSpeedMps: ActivityProfile.run.maxSpeedMps);       // Doppler-based
```

Live, feed each result to a `DistanceAccumulator` with
`add(result, newSegment: ...)`; it gives the same total as `distanceM`.
