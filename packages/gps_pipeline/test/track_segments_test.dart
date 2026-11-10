import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:test/test.dart';

// ~1.11 m per 0.00001 deg of latitude.
RawFix _fix(DateTime t, double lat, double lng,
        {double speed = 3, int acc = 5}) =>
    RawFix(
        lat: lat,
        lng: lng,
        elevation: 0,
        timestamp: t,
        speedMps: speed,
        accuracy: acc);

PipelineResult _res(DateTime t, double lat, FilterStatus status) =>
    PipelineResult(
      raw: _fix(t, lat, 0),
      pointIndex: 0,
      trackVersion: TrackVersion.kalmanEkf,
      smoothedLat: lat,
      smoothedLng: 0,
      filterStatus: status,
    );

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 6);

  group('TrackSegments', () {
    test('a long gap starts a new segment and its jump is not counted', () {
      final results = [
        _res(t0, 0, FilterStatus.filtered),
        _res(t0.add(const Duration(seconds: 1)), 0.00003, FilterStatus.filtered),
        // 2 min pause, 500 m away
        _res(t0.add(const Duration(seconds: 121)), 0.0048, FilterStatus.gapLong),
        _res(t0.add(const Duration(seconds: 122)), 0.00483, FilterStatus.filtered),
      ];
      final segs = TrackSegments.split(results);
      expect(segs.length, 2);
      expect(segs[0].length, 2);
      expect(segs[1].length, 2);
      // ~3.3 m + ~3.3 m; the ~530 m pause chord must not be counted.
      expect(TrackSegments.distanceM(results), lessThan(10));
    });

    test('a short gap is bridged only when the chord is short', () {
      final near = [
        _res(t0, 0, FilterStatus.filtered),
        _res(t0.add(const Duration(seconds: 15)), 0.0003, FilterStatus.gapShort), // ~33 m
      ];
      expect(TrackSegments.split(near).length, 1);
      expect(TrackSegments.distanceM(near), closeTo(33.4, 1));

      final far = [
        _res(t0, 0, FilterStatus.filtered),
        _res(t0.add(const Duration(seconds: 15)), 0.001, FilterStatus.gapShort), // ~111 m
      ];
      expect(TrackSegments.split(far).length, 2);
      expect(TrackSegments.distanceM(far), 0);
    });

    test('rejected results are skipped', () {
      final results = [
        _res(t0, 0, FilterStatus.filtered),
        _res(t0.add(const Duration(seconds: 1)), 0.01, FilterStatus.rejected),
        _res(t0.add(const Duration(seconds: 2)), 0.00003, FilterStatus.filtered),
      ];
      expect(TrackSegments.split(results).single.length, 2);
    });
  });

  group('DistanceAccumulator', () {
    PipelineResult at(int sec, double lat, double lng, double speed, {int acc = 5}) =>
        PipelineResult(
          raw: _fix(t0.add(Duration(seconds: sec)), lat, lng, speed: speed, acc: acc),
          pointIndex: sec,
          trackVersion: TrackVersion.kalmanEkf,
          smoothedLat: lat,
          smoothedLng: lng,
          filterStatus: FilterStatus.filtered,
        );

    test('integrates Doppler speed, ignoring sideways GPS wobble', () {
      // 60 s north at 3 m/s, positions zig-zagging +/-6 m east-west.
      final results = [
        for (var i = 0; i <= 60; i++)
          at(i, i * 0.000027, (i.isEven ? 1 : -1) * 0.000054, 3.0),
      ];
      // Old hop-summing would report ~60 x 12.4 m = ~740 m.
      expect(TrackSegments.distanceM(results), closeTo(180, 1));
    });

    test('without speed, jitter inside the noise adds nothing', () {
      // Standing still, no speed reported, positions jumping within ~5 m.
      final results = [
        for (var i = 0; i < 30; i++)
          at(i, (i % 3) * 0.00002, (i % 2) * 0.00002, -1, acc: 8),
      ];
      expect(TrackSegments.distanceM(results), 0);
    });

    test('without speed, real movement is still counted', () {
      // 100 s east at ~3 m/s, no speed ever reported.
      final results = [
        for (var i = 0; i <= 100; i++) at(i, 0, i * 0.000027, -1),
      ];
      expect(TrackSegments.distanceM(results), closeTo(300, 15));
    });

    test('a briefly missing speed reading is bridged with the last one', () {
      final results = [
        at(0, 0, 0, 3.0),
        at(1, 0.000027, 0, 3.0),
        at(2, 0.000054, 0, -1), // missing
        at(3, 0.000081, 0, 3.0),
      ];
      expect(TrackSegments.distanceM(results), closeTo(9, 0.01));
    });

    test('a Doppler spike above the profile limit is ignored', () {
      final results = [
        at(0, 0, 0, 3.0),
        at(1, 0.000027, 0, 3.0),
        at(2, 0.000054, 0, 80.0), // spike
      ];
      expect(TrackSegments.distanceM(results, maxSpeedMps: 10), lessThan(10));
    });
  });

  group('Unknown device speed', () {
    test('a run with no speed reported is not discarded as "stationary"', () {
      // Previously speed was reported as 0, the stop detector saw a runner
      // "standing still" and rejected every point after 5 s.
      final fixes = [
        for (var i = 0; i < 120; i++)
          _fix(t0.add(Duration(seconds: i)), i * 0.000027, 0, speed: -1),
      ];
      final results = GpsPipeline(profile: ActivityProfile.run).reprocess(fixes);
      final accepted = results.where((r) => r.isAccepted).length;
      expect(accepted, greaterThan(100));
      expect(TrackSegments.distanceM(results), closeTo(357, 30));
    });
  });

  group('KalmanFilter', () {
    test('never emits an invented (predicted) point when a fix is gated out',
        () {
      final kf = KalmanFilter(originLat: 0, originLng: 0);
      // Run north at ~3.3 m/s for 10 s to build up velocity.
      for (var i = 0; i < 10; i++) {
        kf.process(_fix(t0.add(Duration(seconds: i)), i * 0.00003, 0, acc: 3),
            i, TrackVersion.kalmanEkf);
      }
      // Sudden 60 m sideways measurement: must be rejected, not replaced by
      // a dead-reckoned "keep going north" point.
      final r = kf.process(
          _fix(t0.add(const Duration(seconds: 10)), 0.0003, 0.00055, acc: 3),
          10,
          TrackVersion.kalmanEkf);
      expect(r.isAccepted, isFalse);
      expect(r.isDeadReckoned, isFalse);
    });

    test('re-anchors on the measured position after repeated disagreement', () {
      final kf = KalmanFilter(originLat: 0, originLng: 0);
      for (var i = 0; i < 10; i++) {
        kf.process(_fix(t0.add(Duration(seconds: i)), i * 0.00003, 0, acc: 3),
            i, TrackVersion.kalmanEkf);
      }
      PipelineResult? last;
      for (var i = 10; i < 13; i++) {
        last = kf.process(
            _fix(t0.add(Duration(seconds: i)), 0.0003, 0.00055, acc: 3),
            i,
            TrackVersion.kalmanEkf);
      }
      expect(last!.isAccepted, isTrue);
      expect(last.smoothedLat, 0.0003);
      expect(last.smoothedLng, 0.00055);
    });

    test('a fix with no speed is not over-trusted', () {
      // Two filters with identical history; the second measurement is 15 m off
      // with 20 m accuracy and speed 0 (= "unknown" on many devices).
      final kf = KalmanFilter(originLat: 0, originLng: 0);
      for (var i = 0; i < 10; i++) {
        kf.process(_fix(t0.add(Duration(seconds: i)), 0, 0, speed: 0, acc: 5),
            i, TrackVersion.kalmanEkf);
      }
      final r = kf.process(
          _fix(t0.add(const Duration(seconds: 10)), 0.000135, 0,
              speed: 0, acc: 20),
          10,
          TrackVersion.kalmanEkf);
      // Old behaviour capped its variance to a 5 m fix and moved ~1.5 m toward
      // it; weighted by its real 20 m accuracy it should barely move.
      final moved = CoordinateUtil.haversineMetres(0, 0, r.smoothedLat!, 0);
      expect(moved, lessThan(1.0));
    });
  });

  group('GpsPipeline warm-up', () {
    test('a coarse first fix is not used as the start of the track', () {
      final p = GpsPipeline(profile: ActivityProfile.run);
      final r = p.process(_fix(t0, 0, 0, acc: 18));
      expect(r!.isAccepted, isFalse);
      expect(r.rejectReason, RejectReason.poorAccuracy);
    });

    test('a good first fix is accepted immediately', () {
      final p = GpsPipeline(profile: ActivityProfile.run);
      // The spike look-ahead holds early fixes briefly; the first one released
      // must be the first fix, accepted (not gated by the warm-up).
      PipelineResult? first;
      for (var i = 0; i < 4 && first == null; i++) {
        first = p.process(_fix(t0.add(Duration(seconds: i)), i * 0.00003, 0, acc: 6));
      }
      expect(first, isNotNull);
      expect(first!.raw.timestamp, t0);
      expect(first.isAccepted, isTrue);
    });

    test('the warm-up only delays a weak start by 10 s, not forever', () {
      final p = GpsPipeline(profile: ActivityProfile.run);
      PipelineResult? last;
      for (var i = 0; i <= 12; i++) {
        last = p.process(_fix(t0.add(Duration(seconds: i)), i * 0.00003, 0, acc: 18)) ?? last;
      }
      expect(last!.isAccepted, isTrue);
    });

    test('reprocess is deterministic regardless of prior live state', () {
      final fixes = [
        for (var i = 0; i < 60; i++)
          _fix(t0.add(Duration(seconds: i)), i * 0.00003, 0,
              speed: i < 20 || i > 40 ? 3 : 0),
      ];
      final p = GpsPipeline(profile: ActivityProfile.run);
      for (final f in fixes.take(30)) {
        p.process(f);
      }
      final a = p.reprocess(fixes).map((r) => r.filterStatus).toList();
      final b = GpsPipeline(profile: ActivityProfile.run)
          .reprocess(fixes)
          .map((r) => r.filterStatus)
          .toList();
      expect(a, b);
    });
  });
}
