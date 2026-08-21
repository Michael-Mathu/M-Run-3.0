import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo_app/core/gamification/gamification_state.dart';
import 'package:mwendo_app/features/challenges/challenge_evaluator.dart';

void main() {
  group('GamifiedChallenge.value/ratio/isComplete — higher-is-better metric', () {
    test('distanceKm metric reads from cumulative state when no run snapshot is given', () {
      const g = GamificationState(totalDistanceM: 3200);
      final v = ChallengeEvaluator.first5K.value(g);
      expect(v, closeTo(3.2, 1e-9));
    });

    test('distanceKm metric prefers a per-run snapshot over cumulative state', () {
      const g = GamificationState(totalDistanceM: 3200);
      const run = PerRunSnapshot(distanceM: 6000, durationMs: 0, elevationGainM: 0, avgPaceMinPerKm: 0);
      expect(ChallengeEvaluator.first5K.value(g, run: run), closeTo(6.0, 1e-9));
    });

    test('ratio is clamped to [0, 1] even when the target is exceeded', () {
      const g = GamificationState(totalDistanceM: 999000); // 999km, way past any target
      expect(ChallengeEvaluator.first5K.ratio(g), 1.0);
    });

    test('isComplete is false below target, true at/above it', () {
      const below = GamificationState(totalDistanceM: 4000);
      const atTarget = GamificationState(totalDistanceM: 5000);
      expect(ChallengeEvaluator.first5K.isComplete(below), isFalse);
      expect(ChallengeEvaluator.first5K.isComplete(atTarget), isTrue);
    });

    test('streakDays and runs metrics read the matching state fields', () {
      const g = GamificationState(streakDays: 4, totalRuns: 1);
      expect(ChallengeEvaluator.streak7.value(g), 4.0);
      expect(ChallengeEvaluator.sunriseSprint.isComplete(g), isTrue); // target 1 run
    });

    test('lessons and legendsBeaten metrics read set lengths', () {
      const g = GamificationState(
        completedLessons: {'course-a:0', 'course-a:1'},
        beatenLegends: {'kipchoge-marathon'},
      );
      expect(ChallengeEvaluator.bookworm.value(g), 2.0);
      expect(ChallengeEvaluator.beatALegend.isComplete(g), isTrue);
    });
  });

  group('GamifiedChallenge — lowerIsBetter (pace) metrics', () {
    test('faster-than-target pace completes the challenge', () {
      const g = GamificationState(bestPaceMinPerKm: 5.2); // faster than subSix's 6.0 target
      expect(ChallengeEvaluator.subSix.isComplete(g), isTrue);
    });

    test('slower-than-target pace does not complete the challenge', () {
      const g = GamificationState(bestPaceMinPerKm: 7.0);
      expect(ChallengeEvaluator.subSix.isComplete(g), isFalse);
    });

    test('a zero/unset pace (no runs yet) yields ratio 0, not a divide-by-zero blowup', () {
      const g = GamificationState(bestPaceMinPerKm: 0);
      expect(ChallengeEvaluator.subSix.ratio(g), 0.0);
      expect(ChallengeEvaluator.subSix.isComplete(g), isFalse);
    });

    test('ratio for lowerIsBetter is still clamped to [0, 1] for a very fast pace', () {
      const g = GamificationState(bestPaceMinPerKm: 2.0); // far faster than any target
      expect(ChallengeEvaluator.subFive.ratio(g), 1.0);
    });
  });

  group('ChallengeEvaluator library integrity', () {
    test('allChallenges has no duplicate slugs or badge ids', () {
      final slugs = ChallengeEvaluator.allChallenges.map((c) => c.slug).toSet();
      final badgeIds = ChallengeEvaluator.allChallenges.map((c) => c.badgeId).toSet();
      expect(slugs.length, ChallengeEvaluator.allChallenges.length);
      expect(badgeIds.length, ChallengeEvaluator.allChallenges.length);
    });

    test('byCategory returns only challenges in that category', () {
      final starters = ChallengeEvaluator.byCategory(ChallengeCategory.starter);
      expect(starters, isNotEmpty);
      expect(starters.every((c) => c.category == ChallengeCategory.starter), isTrue);
    });

    test('badgeMeta resolves a challenge badge and falls back for an unknown id', () {
      final known = badgeMeta(ChallengeEvaluator.firstRun.badgeId);
      expect(known.name, ChallengeEvaluator.firstRun.badgeName);

      final unknown = badgeMeta('does-not-exist');
      expect(unknown.name, 'does-not-exist');
    });
  });
}
