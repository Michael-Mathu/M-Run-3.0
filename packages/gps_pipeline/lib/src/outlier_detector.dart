import 'dart:math';

import 'coordinate_util.dart';
import 'models.dart';

class OutlierResult {
  final bool isOutlier;
  final RejectReason? rejectReason;

  const OutlierResult.ok()
      : isOutlier = false,
        rejectReason = null;

  const OutlierResult.reject(this.rejectReason) : isOutlier = true;
}

class OutlierDetector {
  final ActivityProfile profile;

  const OutlierDetector({required this.profile});

  OutlierResult check(RawFix prev, RawFix curr, RawFix? next) {
    final dtSec =
        curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (dtSec <= 0)
      return const OutlierResult.reject(RejectReason.invalidTimestamp);

    final dist =
        CoordinateUtil.haversineMetres(prev.lat, prev.lng, curr.lat, curr.lng);
    // Subtract the fixes' own uncertainty before computing speed. At 1 Hz two
    // honest 5 m-accurate fixes can sit ~7 m apart while standing still, which
    // reads as a 7 m/s "sprint"; without this slack the gate is either too
    // strict (drops real points) or has to be set so loose (it was 12 m/s) that
    // a wrong Wi-Fi/cell fix sails through once a few seconds have passed.
    final slackM = 0.5 * (prev.accuracy + curr.accuracy).toDouble();
    final impliedSpeed = max(0.0, dist - slackM) / dtSec;

    // 1. Check if implied speed exceeds maximum for activity
    if (impliedSpeed > profile.maxSpeedMps) {
      return const OutlierResult.reject(RejectReason.excessiveSpeed);
    }

    // 2. Lookahead for 3-point spike (A -> far away B -> near A/C)
    if (next != null) {
      final distToNext = CoordinateUtil.haversineMetres(
          curr.lat, curr.lng, next.lat, next.lng);
      final distPrevToNext = CoordinateUtil.haversineMetres(
          prev.lat, prev.lng, next.lat, next.lng);

      // If B is far from both A and C, but A and C are close, B is a spike
      if (dist > 15.0 && distToNext > 15.0 && distPrevToNext < dist * 0.5) {
        return const OutlierResult.reject(RejectReason.spikeDetected);
      }
    }

    return const OutlierResult.ok();
  }
}
