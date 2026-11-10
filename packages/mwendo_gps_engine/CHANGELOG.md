## Unreleased (2026-11-10) — tracking robustness

* New `locationAccuracy()`: `'precise'`, `'approximate'` (Android 12+
  "Approximate" / iOS 14+ "Precise: Off"), `'none'` or `'unknown'`.
* A failed native start (`FOREGROUND_FAILED`, `FOREGROUND_START_FAILED`,
  permission errors) is now delivered as an error on the `startRecording()`
  stream instead of only being logged, so the app can stop and explain.

## Unreleased (2026-11-10) — instant GPS

* New `warmUp()` / `coolDown()`: a pre-run high-accuracy location request so
  satellites are locked before recording. `warmUp()` returns a stream of
  *preview* fixes (event key `preview: true`, never mixed into the recording
  stream); the first is the OS's cached position, delivered immediately.
* Recording start hands the freshest warm fix (≤ 10 s, ≤ 30 m) to the run as
  its first point, then ends the warm-up (no GNSS cold start in between).
* Android: the recording request no longer uses
  `setWaitForAccurateLocation(true)` (which held back early fixes) and sets
  `setMaxUpdateDelayMillis(0)` (no batching).
* iOS: same API (Core Location at best accuracy while warming; cached
  `manager.location` emitted immediately). Not compiled here (no Xcode).

## Unreleased (2026-11-09)

* **Breaking contract change: unknown speed is now `-1`, not `0`.** Android
  (`MwendoTrackingService`) sends `-1.0` when `Location.hasSpeed()` is false;
  iOS sends `-1.0` when `CLLocation.speed` is negative (invalid); Dart
  `NormalizedFix` maps null/negative to `-1`. Previously a missing speed became
  `0`, which the pipeline's stop detector read as "standing still" and which
  could discard a whole run on phones that don't report speed. Consumers should
  treat `speedMps < 0` as "not reported". `platform_parity_test.dart` covers it.

## 0.2.0

* Platform parity & capture normalization across iOS and Android.
* Emits rich `PlatformMetadata` containing HDOP, satellite count, GNSS fix type, and mock location detection flags.
* Normalized session lifecycle events and battery management profiles.

## 0.1.2

* Android: `MwendoTrackingService.startInForeground()` now wraps
  `ServiceCompat.startForeground()` in a try/catch for `SecurityException`, so a
  denied `POST_NOTIFICATIONS` permission no longer crashes the tracking service
  (it runs without a visible notification on API 33+).
* Dart: `MwendoGpsEngine()` registers its platform handler exactly once (guarded
  by a `_registered` flag), so re-instantiation no longer opens a second
  EventChannel stream or orphans the previous listener.

## 0.1.1

* Build fix for AGP 9 / modern Gradle: `MwendoTrackingService.activityId` is now
  package-visible (was `private`, which broke the plugin's `start`/`stop` result),
  and the `@SuppressLint("MissingPermission")` annotation was removed because
  `androidx.annotation` is not on the plugin's compile classpath. Permission is
  requested at runtime from Dart, so the suppression was unnecessary.

## 0.1.0

* Android: move the GPS subscription into a dedicated `MwendoTrackingService`
  foreground service with a persistent notification (`FOREGROUND_SERVICE_TYPE_LOCATION`),
  so a run keeps recording when the app is backgrounded or the screen is locked.
  The plugin binds to the service and forwards location updates via the EventChannel.
* iOS: keep Core Location updating in the background — `pausesLocationUpdatesAutomatically = false`,
  `activityType = .fitness`, and the `location` background mode declared in the host app.

## 0.0.1

* Initial scaffold.
