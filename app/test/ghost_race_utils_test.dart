import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mwendo_app/features/beat/ghost_race_utils.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';

// A round-numbers ghost for hand-verifiable math: 4 splits of 100s each,
// 1000m per split, 400s/4000m total (100s/km flat pace). legendSlug is a
// dummy value -- fine, since these functions never call GhostPace.legend.
GhostPace _flatGhost() => const GhostPace(
      id: 'test-ghost',
      legendSlug: 'unused',
      name: 'Test Ghost',
      distanceLabel: '4K',
      distanceKm: 4,
      splits: [100, 100, 100, 100],
      totalSeconds: 400,
      description: '',
      accent: Colors.red,
      splitStyle: 'even',
    );

void main() {
  group('ghostExpectedTimeAtDistance', () {
    test('at or before the start, expected time is 0', () {
      final g = _flatGhost();
      expect(ghostExpectedTimeAtDistance(g, 0), 0);
      expect(ghostExpectedTimeAtDistance(g, -5), 0);
    });

    test('at or past the finish, expected time is the ghost total', () {
      final g = _flatGhost();
      expect(ghostExpectedTimeAtDistance(g, 4000), 400.0);
      expect(ghostExpectedTimeAtDistance(g, 5000), 400.0); // past finish, still clamps
    });

    test(
      'FIXED (was DISCOVERED_ISSUES.md #5): at 12.5% of the race (500m of '
      '4000m, 100s/km flat pace), a runner should be ~50s in. The '
      'interpolation previously overstated this by roughly one split '
      '(returned 150s) because it summed take(lowerIndex+1) as the '
      'pre-split baseline, which already included the split the runner is '
      'still inside of.',
      () {
        final g = _flatGhost();
        expect(ghostExpectedTimeAtDistance(g, 500), 50.0);
      },
    );

    test(
      'FIXED (same root cause): at an exact split boundary (half distance '
      '= 2 of 4 splits done), expected time is 200s.',
      () {
        final g = _flatGhost();
        expect(ghostExpectedTimeAtDistance(g, 2000), 200.0);
      },
    );
  });

  group('ghostProjectedFinishTime', () {
    test('at the finish line, projected finish equals elapsed time', () {
      final g = _flatGhost();
      expect(ghostProjectedFinishTime(g, 4000, 400000), 400.0);
    });

    test('holding exactly the ghost pace projects the ghost total', () {
      final g = _flatGhost();
      // 2000m in 200000ms (100s/km, same as the ghost's flat pace).
      expect(ghostProjectedFinishTime(g, 2000, 200000), closeTo(400.0, 1e-9));
    });

    test('running twice as fast as the ghost projects roughly half the finish time', () {
      final g = _flatGhost();
      // 2000m in 100000ms -- twice the ghost's pace.
      expect(ghostProjectedFinishTime(g, 2000, 100000), closeTo(200.0, 1e-9));
    });
  });

  group('computeGhostPosition', () {
    final route = [
      const LatLng(0.0, 0.0),
      const LatLng(0.0, 0.01), // ~1112m east at the equator
      const LatLng(0.0, 0.02), // another ~1112m east
    ];

    test('returns null for a degenerate route or a non-positive distance', () {
      final g = _flatGhost();
      expect(computeGhostPosition(g, 100, [const LatLng(0, 0)]), isNull);
      expect(computeGhostPosition(g, 0, route), isNull);
    });

    test('at the start of the race, position is at (or essentially at) the route start', () {
      final g = _flatGhost();
      final pos = computeGhostPosition(g, 1, route);
      expect(pos, isNotNull);
      expect(pos!.latitude, closeTo(0.0, 1e-6));
      expect(pos.longitude, closeTo(0.0, 1e-3));
    });

    test('at the finish, position is at (or essentially at) the route end', () {
      final g = _flatGhost();
      final pos = computeGhostPosition(g, 4000, route);
      expect(pos, isNotNull);
      expect(pos!.longitude, closeTo(0.02, 1e-3));
    });

    test('at half distance, position is roughly halfway along the route', () {
      final g = _flatGhost();
      final pos = computeGhostPosition(g, 2000, route);
      expect(pos, isNotNull);
      expect(pos!.longitude, closeTo(0.01, 1e-3));
    });
  });

  group('formatSeconds / formatSecondsAsMinSec', () {
    test('formatSeconds shows bare seconds under a minute', () {
      expect(formatSeconds(45), '45s');
      expect(formatSeconds(0), '0s');
    });

    test('formatSeconds shows m:ss at or above a minute', () {
      expect(formatSeconds(60), '1:00');
      expect(formatSeconds(125), '2:05');
    });

    test('formatSecondsAsMinSec always shows m:ss, including under a minute', () {
      expect(formatSecondsAsMinSec(5), '0:05');
      expect(formatSecondsAsMinSec(125), '2:05');
    });
  });

  group('SplitComparison', () {
    test('deltaFormatted signs ahead as negative and behind as positive', () {
      const ahead = SplitComparison(
        splitIndex: 0,
        splitNumber: 1,
        ghostSplitTime: 100,
        userProjectedSplitTime: 95,
        deltaSeconds: -5,
        isAhead: true,
        progressInSplit: 1.0,
      );
      const behind = SplitComparison(
        splitIndex: 0,
        splitNumber: 1,
        ghostSplitTime: 100,
        userProjectedSplitTime: 108,
        deltaSeconds: 8,
        isAhead: false,
        progressInSplit: 1.0,
      );
      expect(ahead.deltaFormatted, '-5s');
      expect(behind.deltaFormatted, '+8s');
    });

    test('statusIcon reflects not-started / ahead / close / behind', () {
      const notStarted = SplitComparison(
        splitIndex: 0, splitNumber: 1, ghostSplitTime: 100,
        userProjectedSplitTime: 100, deltaSeconds: 0, isAhead: false, progressInSplit: 0.0,
      );
      const ahead = SplitComparison(
        splitIndex: 0, splitNumber: 1, ghostSplitTime: 100,
        userProjectedSplitTime: 90, deltaSeconds: -10, isAhead: true, progressInSplit: 1.0,
      );
      const close = SplitComparison(
        splitIndex: 0, splitNumber: 1, ghostSplitTime: 100,
        userProjectedSplitTime: 103, deltaSeconds: 3, isAhead: false, progressInSplit: 1.0,
      );
      const behind = SplitComparison(
        splitIndex: 0, splitNumber: 1, ghostSplitTime: 100,
        userProjectedSplitTime: 120, deltaSeconds: 20, isAhead: false, progressInSplit: 1.0,
      );
      expect(notStarted.statusIcon, '⏳');
      expect(ahead.statusIcon, '🟢');
      expect(close.statusIcon, '🟡');
      expect(behind.statusIcon, '🔴');
    });
  });
}
