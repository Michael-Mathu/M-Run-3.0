import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('PipelineResult.copyWith', () {
    test(
      'regression: preserves smoothedSpeedMps when not explicitly overridden '
      '(previously silently reset to null on every copyWith call, since the '
      'constructor call inside copyWith omitted the field entirely -- see '
      'DISCOVERED_ISSUES.md / docs/BUILD_PLAN.md CQ-16)',
      () {
        final original = PipelineResult(
          raw: RawFix(lat: 0, lng: 0, elevation: 0, timestamp: DateTime(2026), speedMps: 2.5, accuracy: 5),
          pointIndex: 0,
          trackVersion: TrackVersion.kalmanEkf,
          smoothedLat: 0.001,
          smoothedLng: 0.002,
          smoothedSpeedMps: 2.7,
          filterStatus: FilterStatus.filtered,
        );

        final copy = original.copyWith(filterStatus: FilterStatus.gapShort);

        expect(copy.smoothedSpeedMps, 2.7, reason: 'smoothedSpeedMps must survive a copyWith that only changes filterStatus');
        expect(copy.filterStatus, FilterStatus.gapShort);
        // Other fields should still pass through unchanged too.
        expect(copy.smoothedLat, original.smoothedLat);
        expect(copy.smoothedLng, original.smoothedLng);
      },
    );

    test('explicit smoothedSpeedMps overrides the previous value', () {
      final original = PipelineResult(
        raw: RawFix(lat: 0, lng: 0, elevation: 0, timestamp: DateTime(2026), speedMps: 2.5, accuracy: 5),
        pointIndex: 0,
        trackVersion: TrackVersion.kalmanEkf,
        smoothedSpeedMps: 2.7,
        filterStatus: FilterStatus.filtered,
      );

      final copy = original.copyWith(smoothedSpeedMps: 3.1);
      expect(copy.smoothedSpeedMps, 3.1);
    });
  });
}
