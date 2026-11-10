# Mwendo API & Module Reference

This document provides a granular reference for all public interfaces, data models, and REST endpoints across the Mwendo ecosystem.

---

## 1. Package: `gps_pipeline`

### 1.1 Class: `GpsPipeline`
**Namespace:** `package:gps_pipeline/gps_pipeline.dart`

```dart
class GpsPipeline {
  final ActivityProfile profile;

  GpsPipeline({
    required this.profile,
    double? kalmanMotionSigma,
  });

  PipelineResult? process(RawFix fix);
  List<PipelineResult> reprocess(List<RawFix> fixes);
  Future<List<PipelineResult>> reprocessAsync(List<RawFix> fixes);
  void flush();
  void reset();
}
```

#### Method Specifications

##### `process(RawFix fix) -> PipelineResult?`
* **Purpose:** Processes a single GPS fix in real-time. Employs a 1-fix lookahead buffer to catch 3-point spikes.
* **Parameters:** `fix` (`RawFix`) - Raw incoming fix from the GPS engine.
* **Returns:** `PipelineResult?` - `null` while buffered; returns `PipelineResult` once lookahead confirms validity.
* **Error / Rejection:** Rejected points return with `filterStatus == FilterStatus.rejected` and a non-null `rejectReason`.

##### `reprocess(List<RawFix> fixes) -> List<PipelineResult>`
* **Purpose:** Synchronously processes a full array of raw points for historical recalculation.
* **Parameters:** `fixes` (`List<RawFix>`) - Array of raw GPS fixes.
* **Returns:** `List<PipelineResult>` - Processed and smoothed results matching the length of the input.

##### `reprocessAsync(List<RawFix> fixes) -> Future<List<PipelineResult>>`
* **Purpose:** Async wrapper around `reprocess` (same result). Map matching is no longer performed; `MapMatcher` remains in the package but the app does not call it (see ARCHITECTURE.md).

##### `flush() -> PipelineResult?`
* **Purpose:** Flushes any remaining lookahead buffered point when tracking finishes or pauses.

---

### 1.2 Data Structures & Enums

#### `enum ActivityProfile`
```dart
enum ActivityProfile {
  run(maxAccuracyM: 20, maxSpeedMps: 10),   // 36 km/h ceiling
  walk(maxAccuracyM: 25, maxSpeedMps: 4),
  cycle(maxAccuracyM: 20, maxSpeedMps: 20),
  drive(maxAccuracyM: 30, maxSpeedMps: 60),
  hike(maxAccuracyM: 30, maxSpeedMps: 6);

  final double maxAccuracyM;
  final double maxSpeedMps;
}
```

#### `enum FilterStatus`
```dart
enum FilterStatus {
  measured,    // Accepted raw measurement
  filtered,    // Smoothed via Kalman filter
  stationary,  // Part of stationary centroid cluster
  gapShort,    // Minor signal gap (10-60s)
  gapLong,     // Major signal outage (>60s)
  rejected     // Rejected by quality gate / outlier detector
}
```

#### `enum RejectReason`
```dart
enum RejectReason {
  none,
  invalidCoordinates,
  nonMonotonicTime,
  mockLocation,
  poorAccuracy,
  excessiveSpeed,
  threePointSpike,
  kalmanGatingFailed,
  stationaryDrift
}
```

#### `enum TrackVersion`
```dart
enum TrackVersion {
  deviceLive('device_live'),
  kalmanEkf('kalman_ekf'),
  postSessionSmoothed('post_session_smoothed'),
  mapMatchedOsm('map_matched_osm');

  final String id;
  const TrackVersion(this.id);
}
```

#### `enum QualityGrade`
```dart
enum QualityGrade {
  excellent('A', Color(0xFF2BB673)),
  good('B', Color(0xFF8DC63F)),
  acceptable('C', Color(0xFFFFD15C)),
  poor('D', Color(0xFFFF5A1F)),
  unreliable('F', Color(0xFFE53935));

  final String letter;
  final Color color;
  const QualityGrade(this.letter, this.color);
}
```

#### `class RawFix`
```dart
class RawFix {
  final double lat;
  final double lng;
  final double elevation;
  final DateTime timestamp;
  final double speedMps;   // Doppler speed; -1 = not reported (never 0 for "unknown")
  final int? heartRate;
  final int? cadence;
  final int accuracy;
  final double? hdop;
  final int? satelliteCount;
  final String? provider;
  final bool isMocked;
  final String fixType;

  const RawFix({
    required this.lat,
    required this.lng,
    required this.elevation,
    required this.timestamp,
    required this.speedMps,
    this.heartRate,
    this.cadence,
    required this.accuracy,
    this.hdop,
    this.satelliteCount,
    this.provider,
    this.isMocked = false,
    this.fixType = 'unknown',
  });
}
```


#### `class TrackSegments` (added 2026-11-09)
**Namespace:** `package:gps_pipeline/gps_pipeline.dart` (`src/track_segments.dart`)

The single rule for where a track line breaks, shared by the live map, the saved route, distance and GPX export.

```dart
class TrackSegments {
  static const double maxBridgeM = 50;

  /// True at a gapLong, or a gapShort whose chord to the previous point > 50 m.
  static bool startsNewSegment(PipelineResult prev, PipelineResult curr);

  /// True for results that may add distance (filtered or gapShort).
  static bool countsDistance(PipelineResult r);

  /// Accepted results split into drawable line segments.
  static List<List<PipelineResult>> split(List<PipelineResult> results);

  /// Total distance using DistanceAccumulator over every segment.
  static double distanceM(List<PipelineResult> results, {required double maxSpeedMps});
}
```

#### `class DistanceAccumulator` (added 2026-11-09)
Incremental distance estimator used live and for saved runs.

```dart
class DistanceAccumulator {
  DistanceAccumulator({
    double maxSpeedMps,            // speeds above this are ignored
    double fallbackThresholdM = 8, // hop threshold floor
    double fallbackMaxM = 15,      // hop threshold ceiling
    double speedHoldS = 3,         // reuse last speed this long when missing
    double maxSpeedStepS = 5,      // longer steps use the hop fallback
  });

  double get totalM;
  /// Adds one result; returns the metres it contributed.
  double add(PipelineResult r, {required bool newSegment});
  void reset();
}
```

1. With device speed: trapezoid integration of Doppler speed over time.
2. Speed missing: last speed held for up to 3 s.
3. Otherwise: distance from an anchor point once displacement exceeds `accuracy.clamp(8, 15)` m.

---

## 2. Package: `mwendo_app` Domain Models

### 2.1 Class: `RunRecord`
**Namespace:** `package:mwendo_app/data/models/run_record.dart`

```dart
class RunRecord {
  final String id;
  final String type;
  final DateTime startedAt;
  final double distanceM;
  final int durationMs;
  final int movingTimeMs;
  final int calories;
  final double elevationGainM;
  final int avgHeartRate;
  final int avgCadence;
  final List<RawFix> rawFixes;
  final List<PipelineResult> filteredResults;
  final List<PipelineResult>? matchedResults;
  final TrackVersion trackVersion;
  /// Accepted points split into line segments (TrackSegments.split); maps and
  /// GPX draw one line per segment so gaps are never bridged.
  final List<List<LatLng>> routeSegments;
  final String? ghostId;
  final bool? ghostWon;
  final int? ghostRaceVersion;

  /// Converts this record into an offline GhostPace to race against past personal efforts.
  GhostPace toGhostPace({String? customName});
}
```

### 2.2 Class: `ActivityRepository`
**Namespace:** `package:mwendo_app/data/repositories/activity_repository.dart`

```dart
class ActivityRepository {
  final AppDatabase _db;

  ActivityRepository(this._db);

  Future<List<RunRecord>> list();
  Future<RunRecord?> get(String id);
  Future<void> save(RunRecord run);
  Future<void> delete(String id);
}
```

---

## 3. Go Cloud REST API Reference

### 3.1 `POST /api/v1/auth/login`
* **Request:** `{"email": "runner@mwendo.app", "password": "securepassword"}`
* **Response (200 OK):** `{"token": "JWT_BEARER_TOKEN", "user_id": "uuid"}`

### 3.2 `POST /api/v1/activities`
* **Headers:** `Authorization: Bearer <TOKEN>`
* **Request Payload:**
```json
{
  "name": "Morning Forest Run",
  "started_at": "2026-08-16T06:30:00Z",
  "distance_m": 10245.5,
  "duration_s": 2700,
  "moving_time_s": 2640,
  "elevation_gain_m": 142.0,
  "calories": 680,
  "avg_hr": 154,
  "points": [
    {"lat": -1.2921, "lng": 36.8219, "ele": 1680.0, "time": "2026-08-16T06:30:00Z", "speed": 3.8}
  ]
}
```
* **Response (201 Created):** `{"id": "activity_uuid", "status": "persisted"}`

### 3.3 `GET /api/v1/activities/{id}`
* **Query Parameters:** `simplify` (optional float, tolerance in degrees/metres for `ST_Simplify`)
* **Response (200 OK):**
```json
{
  "id": "activity_uuid",
  "name": "Morning Forest Run",
  "distance_m": 10245.5,
  "route": {
    "type": "LineString",
    "coordinates": [[36.8219, -1.2921], [36.8225, -1.2915]]
  }
}
```

### 3.4 `GET /api/v1/leaderboard/weekly`
* **Response (200 OK):**
```json
[
  {"rank": 1, "user_id": "usr_001", "total_distance_m": 75400.0},
  {"rank": 2, "user_id": "usr_002", "total_distance_m": 68200.0}
]
```
