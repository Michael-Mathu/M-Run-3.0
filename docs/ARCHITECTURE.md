# Mwendo Architecture & Technical Design

## 1. High-Level System Architecture

Mwendo is engineered as an offline-first, reactive sports telemetry and geospatial analysis platform. The codebase is organized as a decoupled monorepo separating high-frequency numerical computation, OS platform bindings, local data persistence, and cloud synchronization.

```
+-------------------------------------------------------------------------------+
|                             Flutter Client (app/)                            |
|                                                                               |
|  +--------------------+   +---------------------+   +----------------------+  |
|  | Live Tracking UI   |   | Beat Legends Ghost  |   | Drift SQLite Storage |  |
|  | (MapLibre + HUD)   |   | Pacing Engine       |   | (Activities/Drafts)  |  |
|  +---------▲----------+   +----------▲----------+   +----------▲-----------+  |
|            │                         │                         │              |
|  +---------┴─────────────────────────┴─────────────────────────┴------------+  |
|  |                Riverpod Reactive Domain & State Layer                    |  |
|  |     (TrackingModel, GhostRaceController, GamificationNotifier)          |  |
|  +-----------------------------------▲--------------------------------------+  |
+--------------------------------------┼----------------------------------------+
                                       │
     +---------------------------------┼----------------------------------+
     │ (RawFix stream)                 │ (Method/EventChannel)            │
     ▼                                 ▼                                  │
+-------------------------+  +----------------------------------+         │
| Pure Dart Domain Package|  | Federated Platform Plugin        |         │
| (packages/gps_pipeline) |  | (packages/mwendo_gps_engine)     |         │
|                         |  |                                  |         │
| • FixValidator          |  | • Android Foreground Service     |         │
| • QualityGate           |  | • iOS CLLocationManager Engine   |         │
| • OutlierDetector       |  +----------------------------------+         │
| • 2D ENU Kalman Filter  |                                               │
| • Stationary Clusterer  |  +----------------------------------+         │
| • Signal Gap Detector   |  | Native Rust FFI Engine           |         │
| • TrackSegments/Distance|  | (packages/mwendo_fit_parser)     |         │
| • Session Quality Stats |  | • Fast binary FIT parsing        |         │
+-------------------------+  +----------------------------------+         │
                                                                          │
                                                                          │ (HTTP REST / JSON)
                                                                          ▼
                                             +----------------------------------+
                                             | Go Cloud Backend (backend/)      |
                                             |                                  |
                                             | • PostGIS 16 (Spatial Linestrings|
                                             | • Douglas-Peucker ST_Simplify    |
                                             | • Redis 7 Sorted Set Leaderboard |
                                             | • JWT / Bcrypt Auth System       |
                                             +----------------------------------+
```

---

## 2. Telemetry Processing Pipeline (`packages/gps_pipeline`)

> **Updated 2026-11-09.** Fixes for phantom/jagged lines and distance overshoot changed several stages: a cold-start warm-up gate was added, the Kalman filter no longer dead-reckons (it re-anchors on real fixes), the outlier detector accounts for GPS uncertainty, tracks are split into segments at gaps, distance is integrated from Doppler speed, and post-session map matching is no longer called by the app. Background and measurements: [REVAMP_PLAN.md](REVAMP_PLAN.md).

The GPS pipeline operates as a deterministic multi-stage filter. Raw fixes pass through these stages before producing the display polyline and calculated run metrics:

```
[RawFix]
   │
   ▼
1. FixValidator ─────────────► [Invalid Lat/Lng, Non-monotonic Time, Mocked] ──► REJECT
   │
   ▼
1b. Warm-up gate ────────────► [No point accepted yet AND accuracy > 12m, first 20s] ► REJECT
   │
   ▼
2. QualityGate ──────────────► [Accuracy > profile limit, e.g. 20m Run] ────────► REJECT
   │
   ▼
3. OutlierDetector ──────────► [Uncertainty-adjusted speed > Max OR 3-Point Spike] ► REJECT
   │
   ▼
4. KalmanFilter ─────────────► [2D ENU, Mahalanobis Gate > 25.0] ──► REJECT (re-anchor after 3)
   │
   ▼
5. StationarySuppressor ─────► [Speed < 0.5 m/s for 5s] ──────────────────────► Centroid Cluster
   │
   ▼
6. GapDetector ──────────────► [dt > 10s: gapShort | dt > 60s: gapLong] ──────► Segment Break
   │
   ▼
7. TrackSegments ────────────► [gapLong, or gapShort with chord > 50m] ────────► New line segment
   │
   ▼
8. DistanceAccumulator ──────► [∫ Doppler speed dt; accuracy-aware hop fallback] ► Distance

   (MapMatcher still exists in the package but the app no longer calls it.)
```

### Stage 1: Fix Validator (`FixValidator`)
* Validates geographic latitude $[-90, 90]$ and longitude $[-180, 180]$.
* Enforces strict chronological monotonicity ($t_k > t_{k-1}$).
* Rejects software-mocked or spoofed provider fixes (`isMocked == true`).

### Stage 1b: Warm-up gate (`GpsPipeline`)
Until the first point of a run is accepted, fixes worse than 12 m are rejected for up to 20 s. Cold-start fixes often come from cell towers or Wi-Fi (via mobile data) and are 20–50 m off; accepting one drew a "hook" at the start of the run. After 20 s the gate opens anyway so a run in poor signal still records.

### Stage 2: Quality Gate (`QualityGate`)
* Rejects fixes where horizontal accuracy radius exceeds the activity profile limit:

  | Profile | `maxAccuracyM` | `maxSpeedMps` |
  | :--- | :--- | :--- |
  | run | 20 | 10 |
  | walk | 25 | 4 |
  | cycle | 20 | 20 |
  | hike | 30 | 6 |
  | drive | 30 | 60 |
* Computes inverse-variance weighting factor:
  $$w = \frac{1}{\max(\sigma_{\text{accuracy}}^2, 25.0)}$$
  Capping minimum variance at $25\text{ m}^2$ prevents sensor overfitting.

### Stage 3: Outlier & Spike Detector (`OutlierDetector`)
* Computes implied speed between successive fixes:
  $$v_{\text{implied}} = \frac{\max\left(0,\ \text{Haversine}(P_{k-1}, P_k) - \tfrac{1}{2}(\sigma_{k-1} + \sigma_k)\right)}{\Delta t}$$
  Subtracting half of each fix's accuracy radius stops normal 1 Hz jitter from looking like sprinting. Rejects fixes exceeding the activity profile maximum (e.g. $10\text{ m/s} = 36\text{ km/h}$ for running).
* **3-Point Lookahead Spike Detection**:
  Maintains a 1-point buffer $[A, B, C]$. If point $B$ is $> 15\text{ m}$ away from both $A$ and $C$, but $A$ and $C$ are within $50\%$ of that distance, $B$ is classified as a multipath reflection spike and rejected.

### Stage 4: 2D ENU Kalman Filter (`KalmanFilter`)
* Maps WGS84 spherical coordinates into a local Cartesian tangent plane (East-North-Up in metres) around origin $(\phi_0, \lambda_0)$:
  $$e = (\lambda - \lambda_0) \cdot R \cdot \cos(\phi_0)$$
  $$n = (\phi - \phi_0) \cdot R$$
* State Vector: $x = [e, n, v_e, v_n]^T$
* Dynamic Process Covariance Matrix $Q$ adjusts based on motion state, where $v = \max(v_{\text{device}}, v_{\text{filter}})$ so a fix with no reported speed is not mistaken for "standing still":
  $$\sigma = \begin{cases} 3.0\text{ m/s}^2 & \text{if } v > 0.3\text{ m/s} \\ 0.3\text{ m/s}^2 & \text{if stationary} \end{cases}$$
* Measurement noise $R = \sigma_{\text{accuracy}}^2$ using the fix's real accuracy, floored at 3 m (no upper cap).
* Innovation Gating: Rejects updates where squared Mahalanobis distance exceeds $25.0$ ($\sim 5\sigma$). A gated fix is **dropped**; the filter never emits its own prediction as a track point (the old dead-reckoning drew straight lines through corners). After **3 consecutive** gated fixes the filter re-anchors on the measured position.

### Stage 5: Stationary Suppressor (`StationarySuppressor`)
Eliminates GPS drift when runners pause at traffic lights. Uses a 4-state automaton (*moving, maybeStationary, stationary, maybeMoving*) requiring 5 consecutive seconds of low velocity ($<0.5\text{ m/s}$) to enter or exit stationary state. While stationary, incoming points are aggregated into a weighted centroid cluster.

### Stage 6: Gap Detector (`GapDetector`)
* Flags short sensor blackouts ($10\text{s} < \Delta t \le 60\text{s}$) as `FilterStatus.gapShort`.
* Flags extended outages ($\Delta t > 60\text{s}$) as `FilterStatus.gapLong`, prompting an internal Kalman covariance reinitialization.

### Stage 7: Track segments (`TrackSegments`, `track_segments.dart`)
One rule, shared by the live map, the saved route, distance and GPX export: a new line segment starts at a `gapLong`, or at a `gapShort` whose straight-line chord exceeds 50 m (`maxBridgeM`). Short gaps (a bridge, tree cover) are still joined; pauses and long outages are drawn as gaps, never as a straight "phantom" line. GPX export writes one `<trkseg>` per segment.

### Stage 8: Distance (`DistanceAccumulator`, `track_segments.dart`)
Summing point-to-point hops adds every sideways wobble (~+50% on realistic noise). Distance is instead:
1. **Doppler speed integration** (trapezoid rule) when the device reports speed — the method Apple Watch and Garmin use. Speeds above the profile maximum are ignored; steps longer than 5 s fall back to (3).
2. **Short hold:** if a speed reading is missing, the last speed is reused for up to 3 s.
3. **Fallback hop:** otherwise, distance is counted from an anchor point only once displacement exceeds the fix's accuracy, clamped to 8–15 m, so stationary jitter adds nothing.

The live dashboard and the saved run use the same accumulator (`TrackSegments.distanceM`), so the two numbers agree. Device speed is **−1 when unknown** (never 0) end to end: Android, iOS, `NormalizedFix`, and the pipeline.

### Map Matcher (`MapMatcher`) — not used by the app
The package still contains the OSRM `/match/v1/foot` client, but the app no longer calls it. It uploaded the whole trace over mobile data to a public demo server with car-only road data, would snap park/footpath runs onto roads, and its result wasn't used. Strava and Apple Fitness don't snap runs to roads either.

---

## 3. Crash Recovery & Persistence Architecture

Mwendo employs a durable, offline-first SQLite relational database via Drift:

1. **Active Session Drafts & Point Journaling (`SessionDrafts` & `SessionPoints`)**:
   * Every received GPS fix is synchronously journaled to the `session_points` Drift table.
   * On cold start, `AppDatabase.hasUnfinishedDraft()` detects interrupted sessions, allowing seamless recovery in `AppEngineState.recovering` mode.
2. **Completed Activities (`Activities` & `ActivityPoints`)**:
   * Completed runs are stored in relational tables with full raw fixes and filtered results.
   * `ActivityRepository` exposes async CRUD operations directly to Riverpod providers without legacy JSON dependencies.

---

## 4. "Beat Legends" Virtual Pacing & Offline Ghost Racing

The ghost racing engine simulates legendary performances using dynamic split projection:

* **Ghost Scaling**: Scales target race duration against difficulty tiers:
  * Bronze: $125\%$ of World Record (WR)
  * Silver: $110\%$ of WR
  * Gold: $102\%$ of WR
  * G.O.A.T.: $100\%$ of WR
* **Offline Local Ghost Races**:
  * Users can convert any previously saved `RunRecord` into an offline `GhostPace` using `record.toGhostPace()`, allowing them to race against their personal efforts without internet access.
* **Split Styles**: Mathematical split progression models:
  * *Even*: Stable pace across segments.
  * *Negative*: Progressive acceleration ($\text{factor} = 1.12 - 0.24t$).
  * *Positive*: Front-loaded fast start ($\text{factor} = 0.90 + 0.20t$).
* **Real-Time Spline Interpolation**:
  `ghostExpectedTimeAtDistance(ghost, userDistanceM)` computes continuous expected split times, calculating live time deltas ($\Delta t = t_{\text{user}} - t_{\text{ghost}}$) and projecting finish times.
* **Map Position Projection**:
  `computeGhostPosition(ghost, userDistanceM, routePoints)` computes the ghost's interpolated coordinate along the runner's route polyline and updates an animated MapLibre pulse marker.

---

## 5. Go Cloud Backend & Geospatial Indexing

The backend is built with Go 1.22 and PostGIS 16:

* **Spatial Database Representation**:
  Activities store GPS trajectories as PostGIS `GEOGRAPHY(LineString, 4326)` geometries with spatial GiST indexing.
* **Douglas-Peucker Route Simplification**:
  `GET /api/v1/activities/{id}?simplify=tol` executes `ST_Simplify(route::geometry, tolerance)` directly in PostgreSQL, reducing payload size by up to $85\%$ for mobile map rendering without visible loss of fidelity.
* **Leaderboards with Graceful Degradation**:
  The leaderboard service defaults to Redis Sorted Sets (`ZINCRBY mwendo:leaderboard:weekly <score> <user_id>`). If Redis is unavailable, it automatically degrades to a thread-safe in-memory map protected by `sync.Mutex`.
