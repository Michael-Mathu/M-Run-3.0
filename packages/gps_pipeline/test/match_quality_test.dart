import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:test/test.dart';

PipelineResult _accepted(double lat, DateTime ts) => PipelineResult(
      raw: RawFix(lat: lat, lng: 0, elevation: 0, timestamp: ts, speedMps: 1, accuracy: 5),
      pointIndex: 0,
      trackVersion: TrackVersion.kalmanEkf,
      filterStatus: FilterStatus.filtered,
    );

void main() {
  group('MatchQuality.evaluate', () {
    test('empty matched points or empty filtered results returns the all-fail default', () {
      final r1 = MatchQuality.evaluate(
        [_accepted(0, DateTime(2026))],
        const MatchResult(points: [], meanSnapDistanceM: 0, p95SnapDistanceM: 0, matchedCount: 0, unmatchedCount: 0, providerConfidence: 0),
      );
      expect(r1.passesThresholds, isFalse);
      expect(r1.unmatchedFraction, 1.0);

      final r2 = MatchQuality.evaluate(
        const [],
        const MatchResult(points: [MatchedPoint(lat: 0, lng: 0, snapDistanceM: 0)], meanSnapDistanceM: 0, p95SnapDistanceM: 0, matchedCount: 1, unmatchedCount: 0, providerConfidence: 1),
      );
      expect(r2.passesThresholds, isFalse);
    });

    test('a high unmatched fraction fails the threshold even with a perfect route', () {
      final t0 = DateTime(2026, 1, 1);
      final filtered = [_accepted(0, t0), _accepted(0.001, t0.add(const Duration(seconds: 10)))];
      final matchResult = const MatchResult(
        points: [null, null],
        meanSnapDistanceM: 0,
        p95SnapDistanceM: 0,
        matchedCount: 0,
        unmatchedCount: 2,
        providerConfidence: 0.9,
      );
      final r = MatchQuality.evaluate(filtered, matchResult);
      expect(r.unmatchedFraction, 1.0);
      expect(r.passesThresholds, isFalse);
    });

    test(
      'KNOWN BUG: a perfectly straight, fully-matched, high-confidence route '
      'still fails passesThresholds because routeContinuityScore is '
      'wrong. continuityTotal is incremented in BOTH the heading-agreement '
      'loop and the separate continuity loop, but continuityPassCount only '
      'accumulates from the second loop -- inflating the denominator '
      'against a numerator that never counted those extra increments. '
      'Verified against the real implementation (not hand-derived): for a '
      '4-point dead-straight line, routeContinuityScore comes out 0.4 (2 '
      'passes / 5 total) instead of the true 1.0 (2 passes / 2 total), '
      'putting it below the 0.8 pass threshold. See DISCOVERED_ISSUES.md #6.',
      () {
        final t0 = DateTime(2026, 1, 1);
        final filtered = [
          _accepted(0.000, t0),
          _accepted(0.001, t0.add(const Duration(seconds: 10))),
          _accepted(0.002, t0.add(const Duration(seconds: 20))),
          _accepted(0.003, t0.add(const Duration(seconds: 30))),
        ];
        final matchResult = const MatchResult(
          points: [
            MatchedPoint(lat: 0.000, lng: 0, snapDistanceM: 0),
            MatchedPoint(lat: 0.001, lng: 0, snapDistanceM: 0),
            MatchedPoint(lat: 0.002, lng: 0, snapDistanceM: 0),
            MatchedPoint(lat: 0.003, lng: 0, snapDistanceM: 0),
          ],
          meanSnapDistanceM: 0,
          p95SnapDistanceM: 0,
          matchedCount: 4,
          unmatchedCount: 0,
          providerConfidence: 0.9,
        );

        final r = MatchQuality.evaluate(filtered, matchResult);

        // Every other input to passesThresholds is ideal:
        expect(r.unmatchedFraction, 0.0);
        expect(matchResult.p95SnapDistanceM, lessThan(25));
        expect(matchResult.providerConfidence, greaterThan(0.6));
        expect(r.headingAgreementScore, 1.0);

        // ...yet routeContinuityScore is wrong, and passesThresholds is false.
        expect(r.routeContinuityScore, closeTo(0.4, 1e-9));
        expect(r.passesThresholds, isFalse);
      },
    );
  });
}
