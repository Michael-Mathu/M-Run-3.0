import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:gps_pipeline/src/quality_gate.dart';
import 'package:test/test.dart';

RawFix _fix({required int accuracy}) => RawFix(
      lat: 0,
      lng: 0,
      elevation: 0,
      timestamp: DateTime(2026),
      speedMps: 1.0,
      accuracy: accuracy,
    );

void main() {
  group('QualityGate.accept', () {
    test('zero accuracy is rejected regardless of profile', () {
      final gate = const QualityGate(profile: ActivityProfile.run);
      final r = gate.accept(_fix(accuracy: 0));
      expect(r.passes, isFalse);
      expect(r.weight, 0.0);
      expect(r.rejectReason, RejectReason.zeroAccuracy);
    });

    test('accuracy worse than the profile max is rejected as poorAccuracy', () {
      final gate = const QualityGate(profile: ActivityProfile.run); // maxAccuracyM: 20
      final r = gate.accept(_fix(accuracy: 25));
      expect(r.passes, isFalse);
      expect(r.rejectReason, RejectReason.poorAccuracy);
    });

    test('accuracy within the profile max passes with weight 1/accuracy^2', () {
      final gate = const QualityGate(profile: ActivityProfile.run);
      final r = gate.accept(_fix(accuracy: 10)); // 10^2 = 100 > the 25 floor
      expect(r.passes, isTrue);
      expect(r.rejectReason, isNull);
      expect(r.weight, closeTo(1 / 100, 1e-9));
    });

    test('weight is floored at variance=25 for very accurate fixes (no overfitting)', () {
      final gate = const QualityGate(profile: ActivityProfile.run);
      final r = gate.accept(_fix(accuracy: 2)); // 2^2 = 4, below the 25 floor
      expect(r.passes, isTrue);
      expect(r.weight, closeTo(1 / 25, 1e-9));
    });

    test('different profiles have different accuracy ceilings', () {
      final drive = const QualityGate(profile: ActivityProfile.drive); // maxAccuracyM: 30
      final run = const QualityGate(profile: ActivityProfile.run); // maxAccuracyM: 20
      final fix = _fix(accuracy: 25);
      expect(drive.accept(fix).passes, isTrue);
      expect(run.accept(fix).passes, isFalse);
    });
  });
}
