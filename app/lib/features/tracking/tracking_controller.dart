import 'dart:async';
import 'dart:math';

import '../../data/models/run_record.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_app/data/models/session_draft.dart';
import 'package:mwendo_app/data/repositories/session_draft_repository.dart';
import 'package:mwendo_gps_engine/mwendo_gps_engine.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:latlong2/latlong.dart' as ll;
enum AppEngineState { idle, recording, paused, recovering }

class DisplaySegment {
  final List<TrackPoint> points;
  final FilterStatus type;
  
  const DisplaySegment({required this.points, required this.type});
}

class TrackingState {
  final AppEngineState state;
  final double distanceM;
  final int elapsedMs;
  final int movingTimeMs;
  final double paceMinPerKm; // 0 = unknown
  final int? heartRate;
  final int? cadence;
  final double elevationGainM;
  final int calories;
  final int pointCount; // lightweight signal for UI, avoids copying _pts every tick
  final double currentAccuracy; // latest GPS accuracy for readiness indicator
  final DateTime? lastPointTime; // time of the last received GPS point
  final ActivityProfile profile;

  const TrackingState({
    required this.state,
    this.distanceM = 0,
    this.elapsedMs = 0,
    this.movingTimeMs = 0,
    this.paceMinPerKm = 0,
    this.heartRate,
    this.cadence,
    this.elevationGainM = 0,
    this.calories = 0,
    this.pointCount = 0,
    this.currentAccuracy = double.infinity,
    this.lastPointTime,
    this.profile = ActivityProfile.run,
  });

  static const initial = TrackingState(state: AppEngineState.idle);

  TrackingState copyWith({
    AppEngineState? state,
    double? distanceM,
    int? elapsedMs,
    int? movingTimeMs,
    double? paceMinPerKm,
    int? heartRate,
    int? cadence,
    double? elevationGainM,
    int? calories,
    int? pointCount,
    double? currentAccuracy,
    DateTime? lastPointTime,
    ActivityProfile? profile,
  }) {
    return TrackingState(
        state: state ?? this.state,
        distanceM: distanceM ?? this.distanceM,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        movingTimeMs: movingTimeMs ?? this.movingTimeMs,
        paceMinPerKm: paceMinPerKm ?? this.paceMinPerKm,
        heartRate: heartRate ?? this.heartRate,
        cadence: cadence ?? this.cadence,
        elevationGainM: elevationGainM ?? this.elevationGainM,
        calories: calories ?? this.calories,
        pointCount: pointCount ?? this.pointCount,
        currentAccuracy: currentAccuracy ?? this.currentAccuracy,
        lastPointTime: lastPointTime ?? this.lastPointTime,
        profile: profile ?? this.profile,
      );
  }
}

class TrackingModel extends Notifier<TrackingState> {
  final _engine = MwendoGpsEngine();
  final List<TrackPoint> _pts = [];
  final List<RawFix> _rawFixes = [];
  late GpsPipeline _pipeline;
  
  double _elevationGain = 0;

  /// Elevation hysteresis anchor. GPS altitude wobbles by several metres
  /// fix-to-fix; summing every positive delta inflated "elevation gain" on
  /// flat runs. Only a climb of more than [_elevThresholdM] above the anchor
  /// counts (the same idea Strava/Garmin use).
  double? _elevAnchor;
  static const double _elevThresholdM = 3.0;

  void _trackElevation(double e) {
    final anchor = _elevAnchor;
    if (anchor == null) {
      _elevAnchor = e;
    } else if (e > anchor + _elevThresholdM) {
      _elevationGain += e - anchor;
      _elevAnchor = e;
    } else if (e < anchor - _elevThresholdM) {
      _elevAnchor = e;
    }
  }
  Timer? _ticker;
  DateTime? _runStart;
  int _accumulatedMs = 0;
  int _accumulatedMovingMs = 0;
  DateTime? _lastPtWallClock;
  StreamSubscription<TrackPoint>? _sub;

  // ponytail: the live map polyline is decoupled from the raw GPS stream.
  // Raw points remain the source of truth (DB / GPX / distance / SOS); the
  // pipeline-smoothed _displaySegments is what the map actually draws.
  final List<DisplaySegment> _displaySegments = [];

  /// Serial command queue — prevents start/stop/pause race conditions during
  // rapid pause/resume cycles (blueprint: "lock start/stop commands").
  Future<void>? _lock;

  /// Tracks the most recent recovery write future so `stop()` can await it
  /// before clearing, preventing a stale write from resurrecting a ghost run.
  Future<void>? _pendingWrite;

  /// Accepted GPS points — the source of truth for DB/ GPX/ distance/ SOS.
  List<TrackPoint> get points => _pts;
  
  /// Diagnostic log of every single raw fix.
  List<RawFix> get rawFixes => _rawFixes;

  /// Smoothed, gap-aware segments for the live map polyline.
  List<DisplaySegment> get displaySegments => _displaySegments;

  // Map-ready copies of the display track, maintained incrementally (one
  // LatLng per accepted point) so the Run screen doesn't rebuild the whole
  // route as fresh lists on every 1 Hz rebuild. [routeRevision] bumps on every
  // change; the map uses it to decide when to push the route.
  final List<List<ll.LatLng>> _mapSegments = [];
  final List<ll.LatLng> _flatRoute = [];
  int _routeRevision = 0;
  List<List<ll.LatLng>> get mapSegments => _mapSegments;
  List<ll.LatLng> get flatRoute => _flatRoute;
  int get routeRevision => _routeRevision;

  void _clearMapRoute() {
    _mapSegments.clear();
    _flatRoute.clear();
    _routeRevision++;
  }

  @override
  TrackingState build() {
    _pipeline = GpsPipeline(profile: ActivityProfile.run);
    ref.onDispose(() => _ticker?.cancel());
    return TrackingState.initial;
  }

  void setProfile(ActivityProfile profile) {
    _pipeline = GpsPipeline(profile: profile);
    state = state.copyWith(profile: profile);
  }

  /// Drives `elapsedMs` from the wall clock so the timer ticks live regardless
  /// of GPS quality. GPS only feeds distance/pace; the clock is independent.
  void _startTicker() {
    _runStart = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_runStart == null) return;
      final total =
          _accumulatedMs + DateTime.now().difference(_runStart!).inMilliseconds;
      // Moving time only counts exact GPS deltas. We add an optimistic live tick
      // capped at 10s so the UI feels live between 1hz updates.
      int movingMs = _accumulatedMovingMs;
      if (_pts.isNotEmpty && _pts.last.state == FilterStatus.filtered.name && _lastPtWallClock != null) {
        final liveDelta = DateTime.now().difference(_lastPtWallClock!).inMilliseconds;
        movingMs += min(liveDelta, 10000);
      }
      state = state.copyWith(
        elapsedMs: total,
        movingTimeMs: movingMs,
        calories: (movingMs / 60000 * 11).round(),
      );
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (_runStart != null) {
      _accumulatedMs += DateTime.now().difference(_runStart!).inMilliseconds;
      _runStart = null;
      // Persist current moving time before clearing the moving timer
      _accumulatedMovingMs = state.movingTimeMs;
      _lastPtWallClock = null;
    }
  }

  String? _draftId;

  /// Raw fixes already journaled to disk for the current draft.
  int _journaledCount = 0;

  /// Serializes journal writes so they never overlap or skip points.
  Future<void> _journalChain = Future.value();

  /// Crash-recovery snapshot. Appends only the raw fixes recorded since the
  /// previous write (recovery re-derives everything else from them). The old
  /// version re-filtered the entire run and rewrote every row each time —
  /// O(n) work per write, O(n²) per run, on the UI isolate — which made long
  /// runs progressively laggier.
  Future<void> _writeRecovery() {
    final next = _journalChain.then((_) => _journalNow());
    _journalChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _journalNow() async {
    final id = _draftId;
    if (id == null) return;
    if (_journaledCount > _rawFixes.length) _journaledCount = 0; // list was reset
    final from = _journaledCount;
    final upTo = _rawFixes.length;
    try {
      await ref.read(sessionDraftRepositoryProvider).journalDraft(
            id: id,
            newFixes: _rawFixes.sublist(from, upTo),
            startSeq: from,
            filterVersion: _pipeline.trackVersion,
            distanceM: state.distanceM,
            durationMs: state.elapsedMs,
            movingTimeMs: state.movingTimeMs,
            elevationGainM: _elevationGain,
            calories: state.calories,
            activityType: state.profile,
            createdAt: _rawFixes.isNotEmpty ? _rawFixes.first.timestamp : DateTime.now(),
          );
      if (_draftId == id) _journaledCount = upTo;
    } catch (_) {
      // offline-first: best-effort; the next write retries from `from`.
    }
  }

  /// Removes the on-disk draft — call once a run has been finalized (saved
  /// as a completed activity) or explicitly discarded by the user, so it
  /// stops being offered for recovery. [draftId] lets callers pass the id
  /// captured before `_draftId` was cleared for the next run.
  Future<void> _clearRecovery([String? draftId]) async {
    final id = draftId ?? _draftId;
    if (id == null) return;
    try {
      await ref.read(sessionDraftRepositoryProvider).deleteDraft(id);
    } catch (_) {
      // best-effort cleanup — a leftover row is harmless, just re-offered
      // as recoverable next launch.
    }
  }

  /// True if a previously interrupted run was journaled to the DB and is
  /// still awaiting finalization.
  Future<bool> hasRecoverableRun() async {
    try {
      final draft = await ref.read(sessionDraftRepositoryProvider).getRecoverable();
      return draft != null && draft.rawFixes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Load an interrupted run from the Drift-backed draft journal and resume
  /// it in a `recovering` state.
  Future<void> restoreInterrupted() async {
    try {
      final draft = await ref.read(sessionDraftRepositoryProvider).getRecoverable();
      if (draft == null) return;

      _draftId = draft.id;
      _rawFixes
        ..clear()
        ..addAll(draft.rawFixes);
      _journaledCount = _rawFixes.length;

      _pts.clear();
      _displaySegments.clear();
      _clearMapRoute();
      _pipeline = GpsPipeline(profile: draft.activityType);

      // Reconstruct accepted points silently through the exact same path a
      // live point takes, so the restored line obeys the same segment rules.
      _lastAccepted = null;
      _resetDistance();
      _restoring = true;
      try {
        for (final p in _rawFixes) {
          final r = _pipeline.process(p);
          if (r != null) _handleResult(r);
        }
        for (final r in _pipeline.flush()) {
          _handleResult(r);
        }
      } finally {
        _restoring = false;
      }
      // The app was killed in between: treat the restart like a resume.
      _resumedSinceLastPoint = true;
      _pipeline.reset();

      _elevationGain = draft.elevationGainM;
      _elevAnchor = null;
      _accumulatedMs = draft.durationMs;
      _accumulatedMovingMs = draft.movingTimeMs;
      state = state.copyWith(
        state: AppEngineState.recovering,
        distanceM: draft.distanceM,
        elapsedMs: draft.durationMs,
        movingTimeMs: draft.movingTimeMs,
        elevationGainM: _elevationGain,
        pointCount: _pts.length,
        profile: draft.activityType,
      );
    } catch (_) {
      // corrupt/partial snapshot — ignore, treat as unrecoverable
    }
  }

  Future<void> start() => _enqueue(() => _start());

  Future<void> _start() async {
    // If a previous run was interrupted, continue from where we left off.
    if (await hasRecoverableRun()) {
      await restoreInterrupted();
      if (state.state == AppEngineState.recovering) {
        // restoreInterrupted() only loads the saved points/state. The engine is
        // started here (and only here, via the permission-gated start/resume
        // path) so a recovered run actually records (fixes C3) without ever
        // auto-starting GPS on page load — which crashed when location
        // permission wasn't granted yet.
        _sub?.cancel();
        _sub = _engine.startRecording().listen(
          _onPoint,
          onError: (e, st) {
            debugPrint('GPS stream error during recovery: $e');
          },
        );
        _startTicker();
        state = state.copyWith(state: AppEngineState.recording);
        return;
      }
    }
    _pts.clear();
    _rawFixes.clear();
    _displaySegments.clear();
    _clearMapRoute();
    _lastAccepted = null;
    _resumedSinceLastPoint = false;
    _resetDistance();
    _elevationGain = 0;
    _elevAnchor = null;
    _accumulatedMs = 0;
    _accumulatedMovingMs = 0;
    _lastPtWallClock = null;
    _draftId = RunRecord.newId();
    _journaledCount = 0;
    state = state.copyWith(
      state: AppEngineState.recording,
      distanceM: 0,
      elapsedMs: 0,
      movingTimeMs: 0,
      paceMinPerKm: 0,
      heartRate: null,
      cadence: null,
      elevationGainM: 0,
      calories: 0,
      pointCount: 0,
    );
    _startTicker();
    _sub?.cancel();
    _sub = _engine.startRecording().listen(
      _onPoint,
      onError: (e, st) {
        // Stream errors (e.g., SecurityException after fresh permission grant)
        // must be handled instead of crashing the app.
        debugPrint('GPS stream error: $e');
      },
    );
  }

  void _onPoint(TrackPoint p) {
    final raw = RawFix(
      lat: p.lat,
      lng: p.lng,
      elevation: p.elevation,
      timestamp: p.timestamp,
      speedMps: p.speedMps,
      heartRate: p.heartRate,
      cadence: p.cadence,
      accuracy: p.accuracy,
      hdop: p.hdop,
      satelliteCount: p.satelliteCount,
      provider: p.provider,
      isMocked: p.isMocked,
      fixType: p.fixType,
    );
    _rawFixes.add(raw);

    final result = _pipeline.process(raw);
    if (result == null) return; // buffered

    _handleResult(result, p);
  }

  /// Runs a full-session reprocess on a *separate* pipeline instance. The old
  /// code called `_pipeline.reprocess` on the live instance — every 10 points
  /// (recovery snapshot) that reset the live filter mid-run and silently
  /// dropped the two points sitting in its look-ahead buffer.
  List<PipelineResult> _reprocessAll() {
    // Stop and buildRunRecord both need this; reuse the result while the raw
    // fixes and profile are unchanged (the list only ever grows or clears).
    final cached = _reprocessCache;
    if (cached != null &&
        cached.count == _rawFixes.length &&
        cached.profile == state.profile &&
        (_rawFixes.isEmpty || identical(cached.last, _rawFixes.last))) {
      return cached.results;
    }
    final results = GpsPipeline(profile: state.profile).reprocess(_rawFixes);
    _reprocessCache = (
      count: _rawFixes.length,
      profile: state.profile,
      last: _rawFixes.isEmpty ? null : _rawFixes.last,
      results: results,
    );
    return results;
  }

  ({int count, ActivityProfile profile, RawFix? last, List<PipelineResult> results})?
      _reprocessCache;

  /// Last accepted result, used to apply [TrackSegments] rules live.
  PipelineResult? _lastAccepted;

  /// Live odometer — same estimator the saved run uses (Doppler speed first,
  /// noise-gated position hops as fallback), so live and saved distance agree.
  DistanceAccumulator _distance = DistanceAccumulator();

  void _resetDistance() =>
      _distance = DistanceAccumulator(maxSpeedMps: state.profile.maxSpeedMps);

  /// Set on resume: the first point after a pause must not be joined to the
  /// pre-pause point if the runner moved while paused.
  bool _resumedSinceLastPoint = false;

  /// True while [restoreInterrupted] replays a saved draft (suppresses the
  /// periodic recovery write, which would otherwise save a half-replayed run).
  bool _restoring = false;

  /// Whether [result] starts a new line relative to the previous point. Same
  /// rule as the saved route ([TrackSegments.startsNewSegment]); additionally a
  /// pause is always treated as a gap, because the live pipeline is reset on
  /// pause and so cannot itself see the time gap.
  bool _startsNewSegment(PipelineResult result) {
    final prev = _lastAccepted;
    if (prev == null) return true;
    if (TrackSegments.startsNewSegment(prev, result)) return true;
    return _resumedSinceLastPoint &&
        TrackSegments.chordM(prev, result) > TrackSegments.maxBridgeM;
  }

  void _handleResult(PipelineResult result, [TrackPoint? originalPt]) {
    if (!result.isAccepted) {
        // ponytail: diagnostics only. Do not accumulate distance or pace.
        return;
    }

    final isFiltered = result.filterStatus == FilterStatus.filtered;

    final smoothedLat = result.smoothedLat ?? result.raw.lat;
    final smoothedLng = result.smoothedLng ?? result.raw.lng;
    final smoothedSpeed = result.smoothedSpeedMps ?? result.raw.speedMps;

    final newSegment = _startsNewSegment(result);

    // Never credits the straight-line jump across a pause / long dropout.
    final d = _distance.add(result, newSegment: newSegment);
    if (_pts.isNotEmpty) {
      final prev = _pts.last;

      if (isFiltered && prev.state == FilterStatus.filtered.name) {
        final deltaMs = result.raw.timestamp.difference(prev.timestamp).inMilliseconds;
        if (deltaMs > 0 && deltaMs <= 10000) {
          _accumulatedMovingMs += deltaMs;
        }
      }
    }
    
    _trackElevation(result.raw.elevation);
    _lastPtWallClock = DateTime.now();

    state = state.copyWith(
      state: AppEngineState.recording,
      distanceM: state.distanceM + d,
      // Below ~0.5 m/s (slow walk) the speed is GPS jitter, not pace.
      paceMinPerKm: (isFiltered && smoothedSpeed > 0.5) ? 1000 / (smoothedSpeed * 60) : state.paceMinPerKm,
      heartRate: originalPt?.heartRate ?? result.raw.heartRate,
      cadence: originalPt?.cadence ?? result.raw.cadence,
      elevationGainM: _elevationGain,
      pointCount: _pts.length + 1,
      currentAccuracy: result.raw.accuracy.toDouble(),
      lastPointTime: DateTime.now(),
    );

    // ponytail: Store the smoothed/accepted coordinates in the points array
    // so that later downstream clients don't accidentally compute distance on raw.
    final acceptedPt = TrackPoint(
      raw: NormalizedFix(
        lat: smoothedLat,
        lng: smoothedLng,
        elevation: originalPt?.elevation ?? result.raw.elevation,
        timestamp: originalPt?.timestamp ?? result.raw.timestamp,
        speedMps: originalPt?.speedMps ?? result.raw.speedMps,
        accuracyM: (originalPt?.accuracy ?? result.raw.accuracy).toDouble(),
        hdop: originalPt?.hdop ?? result.raw.hdop,
        satelliteCount: originalPt?.satelliteCount ?? result.raw.satelliteCount,
        provider: originalPt?.provider ?? result.raw.provider ?? 'unknown',
        isMocked: originalPt?.isMocked ?? result.raw.isMocked,
        fixType: originalPt?.fixType ?? result.raw.fixType,
      ),
      heartRate: originalPt?.heartRate ?? result.raw.heartRate,
      cadence: originalPt?.cadence ?? result.raw.cadence,
      state: originalPt?.state ?? result.filterStatus.name,
    );
    _pts.add(acceptedPt);
    _addDisplayPoint(acceptedPt, result, newSegment: newSegment);
    _lastAccepted = result;
    _resumedSinceLastPoint = false;

    if (!_restoring && _pts.length % 10 == 0) {
      _pendingWrite = _writeRecovery();
    }
  }

  void _addDisplayPoint(TrackPoint rawPoint, PipelineResult result,
      {required bool newSegment}) {
    if (!result.isAccepted) return;
    
    final pt = TrackPoint(
      raw: NormalizedFix(
        lat: result.smoothedLat ?? result.raw.lat,
        lng: result.smoothedLng ?? result.raw.lng,
        elevation: result.raw.elevation,
        timestamp: result.raw.timestamp,
        speedMps: result.raw.speedMps,
        accuracyM: result.raw.accuracy.toDouble(),
        hdop: result.raw.hdop,
        satelliteCount: result.raw.satelliteCount,
        provider: result.raw.provider ?? 'unknown',
        isMocked: result.raw.isMocked,
        fixType: result.raw.fixType,
      ),
      heartRate: result.raw.heartRate,
      cadence: result.raw.cadence,
      state: result.filterStatus.name,
    );

    // A pause or long dropout starts a new line (see TrackSegments) instead of
    // drawing a straight chord through places the runner never went.
    if (newSegment || _displaySegments.isEmpty) {
      _displaySegments.add(DisplaySegment(points: [pt], type: result.filterStatus));
    } else {
      _displaySegments.last.points.add(pt);
    }
    final point = ll.LatLng(pt.lat, pt.lng);
    if (newSegment || _mapSegments.isEmpty) {
      _mapSegments.add([point]);
    } else {
      _mapSegments.last.add(point);
    }
    _flatRoute.add(point);
    _routeRevision++;
  }



  RunRecord buildRunRecord(String type, {String? ghostId, bool? ghostWon, int? ghostRaceVersion}) {
    final results = _reprocessAll();
    final rawFixes = _rawFixes.toList(growable: false);
    
    int hrSum = 0, hrCount = 0, cadenceSum = 0, cadenceCount = 0;
    for (final p in rawFixes) {
      if (p.heartRate != null) { hrSum += p.heartRate!; hrCount++; }
      if (p.cadence != null) { cadenceSum += p.cadence!; cadenceCount++; }
    }

    return RunRecord.fromFiltered(
      id: RunRecord.newId(),
      type: type,
      startedAt: rawFixes.isNotEmpty ? rawFixes.first.timestamp : DateTime.now(),
      distanceM: TrackSegments.distanceM(results, maxSpeedMps: state.profile.maxSpeedMps),
      durationMs: state.elapsedMs,
      movingTimeMs: state.movingTimeMs > 0 ? state.movingTimeMs : state.elapsedMs,
      calories: state.calories,
      elevationGainM: state.elevationGainM,
      avgHeartRate: hrCount > 0 ? (hrSum / hrCount).round() : 0,
      avgCadence: cadenceCount > 0 ? (cadenceSum / cadenceCount).round() : 0,
      rawFixes: rawFixes,
      filteredResults: results,
      trackVersion: _pipeline.trackVersion,
      ghostId: ghostId,
      ghostWon: ghostWon,
      ghostRaceVersion: ghostRaceVersion,
    );
  }

  void pause() => _enqueue(() async {
        _engine.pause();
        _stopTicker();
        for (final r in _pipeline.flush()) {
          _handleResult(r);
        }
        _pipeline.reset();
        _pendingWrite = _writeRecovery();
        await _pendingWrite;
        state = state.copyWith(state: AppEngineState.paused);
      });

  void resume() => _enqueue(() async {
        // If the engine was never started (e.g. a recovered run the user is
        // resuming from the `recovering` state), begin it through _start()
        // rather than _engine.resume(), which would be a silent no-op.
        if (_sub == null) {
          await _start();
          return;
        }
        _engine.resume();
        _resumedSinceLastPoint = true;
        _startTicker();
        state = state.copyWith(state: AppEngineState.recording);
      });

  Future<SessionDraft?> stop() => _enqueueWithResult(() async {
        // Await any in-flight recovery write before clearing — prevents
        // the race where _writeRecovery writes after _clearRecovery deletes
        // the file (fixes Bug #8).
        await _pendingWrite;

        _sub?.cancel();
        _sub = null;
        _stopTicker();

        for (final r in _pipeline.flush()) {
          _handleResult(r);
        }
        
        SessionDraft? finalDraft;
        
        if (_draftId != null) {
          final filtered = _reprocessAll();

          final draft = SessionDraft(
            id: _draftId!,
            rawFixes: _rawFixes.toList(growable: false),
            filteredResults: filtered,
            filterVersion: _pipeline.trackVersion,
            filteredDistanceM: TrackSegments.distanceM(filtered,
                maxSpeedMps: state.profile.maxSpeedMps),
            durationMs: state.elapsedMs,
            movingTimeMs: state.movingTimeMs,
            elevationGainM: _elevationGain,
            calories: state.calories,
            status: PostProcessingStatus.pending,
            qualityReport: SessionQualityReport.compute(filtered),
            activityType: state.profile,
            createdAt: _rawFixes.isNotEmpty ? _rawFixes.first.timestamp : DateTime.now(),
          );
          await ref.read(sessionDraftRepositoryProvider).saveDraft(draft);
          
          // Post-run road snapping (MapMatchJob) is intentionally NOT run.
          // It uploaded the whole trace over mobile data to the public OSRM
          // demo server, which only routes for cars — snapping footpaths,
          // parks and tracks onto the nearest road — and nothing in the app
          // read its output (see DISCOVERED_ISSUES.md #3). Strava and Apple
          // Fitness don't snap runs to roads either.
          finalDraft = draft;
        }
        final clearedDraftId = _draftId;
        _draftId = null;

        _pipeline.reset();

        _pts.clear(); // Clear points before recovery clear (fixes Bug #7)
        _rawFixes.clear();
        _displaySegments.clear();
        _clearMapRoute();
        _lastAccepted = null;
        await _engine.stop();
        await _clearRecovery(clearedDraftId);
        state = TrackingState.initial;
        return finalDraft;
      });

  Future<void> discardRecovery() => _enqueue(() async {
        await _clearRecovery(_draftId);
        _draftId = null;
        _pts.clear();
        _rawFixes.clear();
        _displaySegments.clear();
        _clearMapRoute();
        state = TrackingState.initial;
      });

  Future<void> _enqueue(Future<void> Function() op) {
    return _enqueueWithResult<void>(() async {
      await op();
    });
  }

  Future<T> _enqueueWithResult<T>(Future<T> Function() op) {
    final prev = _lock;
    final completer = Completer<T>();
    _lock = completer.future;
    (prev ?? Future.value()).then((_) async {
      try {
        final result = await op();
        completer.complete(result);
      } catch (e, st) {
        // If _start() throws (e.g. platform exception from the GPS engine),
        // propagate the error to the caller so it can rollback state, rather
        // than silently leaving the engine in a corrupt "recording" state.
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

final trackingModelProvider = NotifierProvider<TrackingModel, TrackingState>(TrackingModel.new);
