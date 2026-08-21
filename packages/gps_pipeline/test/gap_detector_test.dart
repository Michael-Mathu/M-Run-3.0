import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:gps_pipeline/src/gap_detector.dart';
import 'package:test/test.dart';

PipelineResult _result(DateTime ts, {FilterStatus status = FilterStatus.filtered}) =>
    PipelineResult(
      raw: RawFix(lat: 0, lng: 0, elevation: 0, timestamp: ts, speedMps: 1, accuracy: 5),
      pointIndex: 0,
      trackVersion: TrackVersion.kalmanEkf,
      filterStatus: status,
    );

void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);
  const detector = GapDetector(); // defaults: 10s short, 60s long

  group('GapDetector.process', () {
    test('a rejected result passes through unchanged', () {
      final r = _result(t0, status: FilterStatus.rejected);
      final out = detector.process(r, _result(t0.subtract(const Duration(seconds: 5))));
      expect(out.filterStatus, FilterStatus.rejected);
    });

    test('no previous result (first point) passes through unchanged', () {
      final r = _result(t0);
      final out = detector.process(r, null);
      expect(out.filterStatus, FilterStatus.filtered);
    });

    test('a rejected previous result is treated the same as no previous result', () {
      final r = _result(t0);
      final prev = _result(t0.subtract(const Duration(seconds: 5)), status: FilterStatus.rejected);
      final out = detector.process(r, prev);
      expect(out.filterStatus, FilterStatus.filtered);
    });

    test('a gap at or under 10s does not change filterStatus', () {
      final prev = _result(t0);
      final r = _result(t0.add(const Duration(seconds: 10)));
      final out = detector.process(r, prev);
      expect(out.filterStatus, FilterStatus.filtered);
    });

    test('a gap over 10s but at or under 60s is flagged gapShort', () {
      final prev = _result(t0);
      final r = _result(t0.add(const Duration(seconds: 11)));
      final out = detector.process(r, prev);
      expect(out.filterStatus, FilterStatus.gapShort);
    });

    test('a gap at exactly 60s is still gapShort (long is a strict >60 check)', () {
      final prev = _result(t0);
      final r = _result(t0.add(const Duration(seconds: 60)));
      final out = detector.process(r, prev);
      expect(out.filterStatus, FilterStatus.gapShort);
    });

    test('a gap over 60s is flagged gapLong', () {
      final prev = _result(t0);
      final r = _result(t0.add(const Duration(seconds: 61)));
      final out = detector.process(r, prev);
      expect(out.filterStatus, FilterStatus.gapLong);
    });

    test('custom thresholds are honored', () {
      const tight = GapDetector(maxContinuousGapSeconds: 2, longGapSeconds: 5);
      final prev = _result(t0);
      final r = _result(t0.add(const Duration(seconds: 3)));
      expect(tight.process(r, prev).filterStatus, FilterStatus.gapShort);
    });
  });
}
