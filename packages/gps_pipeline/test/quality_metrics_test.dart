import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:test/test.dart';

PipelineResult _accepted(double lat, DateTime ts, int accuracy) => PipelineResult(
      raw: RawFix(lat: lat, lng: 0, elevation: 0, timestamp: ts, speedMps: 1, accuracy: accuracy),
      pointIndex: 0,
      trackVersion: TrackVersion.kalmanEkf,
      filterStatus: FilterStatus.filtered,
    );

PipelineResult _rejected(double lat, DateTime ts, int accuracy, RejectReason reason) => PipelineResult(
      raw: RawFix(lat: lat, lng: 0, elevation: 0, timestamp: ts, speedMps: 1, accuracy: accuracy),
      pointIndex: 0,
      trackVersion: TrackVersion.kalmanEkf,
      filterStatus: FilterStatus.rejected,
      rejectReason: reason,
    );

void main() {
  group('SessionQualityReport.compute', () {
    test('an empty result list produces an all-zero, poor-grade report without throwing', () {
      final r = SessionQualityReport.compute(const []);
      expect(r.rejectionRatePct, 0);
      expect(r.medianAccuracyM, 0);
      expect(r.p95AccuracyM, 0);
      expect(r.rejectedCount, 0);
      expect(r.grade, QualityGrade.poor);
    });

    test('a straight-line, all-filtered session grades excellent with 0% rejection', () {
      final t0 = DateTime(2026, 1, 1);
      final results = List.generate(
        10,
        (i) => _accepted(0.0001 * i, t0.add(Duration(seconds: i)), 5),
      );
      final r = SessionQualityReport.compute(results);
      expect(r.rejectedCount, 0);
      expect(r.rejectionRatePct, 0);
      expect(r.percentIdeal, 100);
      expect(r.grade, QualityGrade.excellent);
      expect(r.rawDistanceM, greaterThan(0));
      expect(r.filteredDistanceM, closeTo(r.rawDistanceM, 1e-6));
    });

    test('a mix of accepted and one excessive-speed-rejected point computes distance, jumps, and grade correctly', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      // Four collinear points, ~111.195m apart (0.001 deg lat steps), one
      // rejected in the middle for excessive speed.
      final results = [
        _accepted(0.000, t0, 5),
        _accepted(0.001, t0.add(const Duration(seconds: 10)), 8),
        _rejected(0.002, t0.add(const Duration(seconds: 11)), 100, RejectReason.excessiveSpeed),
        _accepted(0.003, t0.add(const Duration(seconds: 12)), 6),
      ];

      final r = SessionQualityReport.compute(results);

      expect(r.rejectedCount, 1);
      expect(r.rejectionRatePct, closeTo(25.0, 1e-9)); // 1 of 4

      // Sorted accuracies [5, 6, 8, 100]: median = index 2 = 8, p95 = index 3 = 100.
      expect(r.medianAccuracyM, 8.0);
      expect(r.p95AccuracyM, 100.0);

      // Raw and filtered distance both sum to ~3 * 111.195m on this
      // collinear track (filtered skips the rejected middle point, but the
      // total straight-line distance comes out the same either way here).
      expect(r.rawDistanceM, closeTo(333.585, 1));
      expect(r.filteredDistanceM, closeTo(333.585, 1));

      // 1 excessive-speed jump over ~0.333585km of filtered distance.
      expect(r.jumpsPerKm, 3);

      // 3 of 4 results are accepted+filtered => 75% ideal => "fair" (60-80%).
      expect(r.percentIdeal, closeTo(75.0, 1e-9));
      expect(r.grade, QualityGrade.fair);
    });

    test('gap-flagged and stationary results are counted in their own tallies, not as plain filtered', () {
      final t0 = DateTime(2026, 1, 1);
      final results = [
        _accepted(0, t0, 5),
        PipelineResult(
          raw: RawFix(lat: 0.0001, lng: 0, elevation: 0, timestamp: t0.add(const Duration(seconds: 15)), speedMps: 0, accuracy: 5),
          pointIndex: 1,
          trackVersion: TrackVersion.kalmanEkf,
          filterStatus: FilterStatus.gapShort,
        ),
        PipelineResult(
          raw: RawFix(lat: 0.0002, lng: 0, elevation: 0, timestamp: t0.add(const Duration(seconds: 16)), speedMps: 0, accuracy: 5),
          pointIndex: 2,
          trackVersion: TrackVersion.kalmanEkf,
          filterStatus: FilterStatus.stationary,
        ),
      ];
      final r = SessionQualityReport.compute(results);
      expect(r.signalGapCount, 1);
      expect(r.gapCount, 1);
      expect(r.stationaryClusterCount, 1);
      // Neither gap nor stationary results count toward "ideal" filtered points.
      expect(r.percentIdeal, closeTo(100 / 3, 1e-6));
    });
  });
}
