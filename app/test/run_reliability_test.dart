import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/core/audio/voice_coach.dart';
import 'package:mwendo_app/core/device/keep_alive.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/profile/profile_provider.dart';
import 'package:mwendo_app/core/utils/calories.dart';
import 'package:mwendo_app/features/tracking/auto_pause.dart';
import 'package:mwendo_gps_engine/mwendo_gps_engine.dart';

void main() {
  group('estimateCalories', () {
    int kcal(ActivityProfile p,
            {double kg = 70,
            double km = 5,
            double climb = 0,
            int movingMin = 30,
            int elapsedMin = 30}) =>
        estimateCalories(
          profile: p,
          weightKg: kg,
          distanceM: km * 1000,
          elevationGainM: climb,
          movingMs: movingMin * 60000,
          elapsedMs: elapsedMin * 60000,
        );

    test('a 70 kg runner burns about 360 kcal over 5 km', () {
      expect(kcal(ActivityProfile.run), closeTo(360, 5));
    });

    test('scales with body weight', () {
      expect(kcal(ActivityProfile.run, kg: 90), greaterThan(kcal(ActivityProfile.run, kg: 60)));
      expect(kcal(ActivityProfile.run, kg: 140) / kcal(ActivityProfile.run, kg: 70), closeTo(2, 0.02));
    });

    test('walking costs less than running the same distance', () {
      expect(kcal(ActivityProfile.walk), lessThan(kcal(ActivityProfile.run)));
      expect(kcal(ActivityProfile.walk), closeTo(255, 5));
    });

    test('climbing adds energy', () {
      expect(kcal(ActivityProfile.hike, climb: 300), greaterThan(kcal(ActivityProfile.hike)));
    });

    test('cycling uses speed: 20 km in an hour is 8 MET', () {
      expect(kcal(ActivityProfile.cycle, km: 20, movingMin: 60), 560);
      expect(kcal(ActivityProfile.cycle, km: 20, movingMin: 0), 0);
    });

    test('nothing for a drive, nothing before any distance', () {
      expect(kcal(ActivityProfile.drive, km: 40), 0);
      expect(kcal(ActivityProfile.run, km: 0), 0);
    });
  });

  group('AutoPauseDetector', () {
    final t0 = DateTime(2026, 11, 16, 6);
    // ~1.1 m of latitude per 0.00001 degrees.
    AutoPauseChange feed(AutoPauseDetector d, int second,
            {double speed = 0, double northM = 0, double accuracy = 6}) =>
        d.update(
          lat: -1.29 + northM / 111320,
          lng: 36.82,
          speedMps: speed,
          accuracyM: accuracy,
          timestamp: t0.add(Duration(seconds: second)),
        );

    test('does not pause while running', () {
      final d = AutoPauseDetector(ActivityProfile.run);
      for (var i = 0; i < 60; i++) {
        expect(feed(d, i, speed: 3, northM: i * 3.0), AutoPauseChange.none);
      }
      expect(d.isPaused, isFalse);
    });

    test('pauses after standing still for 8 seconds, then resumes on movement', () {
      final d = AutoPauseDetector(ActivityProfile.run);
      var changes = <AutoPauseChange>[];
      for (var i = 0; i <= 8; i++) {
        changes.add(feed(d, i));
      }
      expect(changes.sublist(0, 8), everyElement(AutoPauseChange.none));
      expect(changes.last, AutoPauseChange.paused);
      expect(d.lastStillDuration, const Duration(seconds: 8));

      // One fast fix is not enough (GPS speed spikes while standing).
      expect(feed(d, 9, speed: 2.5), AutoPauseChange.none);
      expect(feed(d, 10, speed: 0), AutoPauseChange.none);
      expect(feed(d, 11, speed: 2.5, northM: 2), AutoPauseChange.none);
      expect(feed(d, 12, speed: 2.5, northM: 5), AutoPauseChange.resumed);
      expect(d.isPaused, isFalse);
    });

    test('a phone that reports no speed never pauses a moving runner', () {
      final d = AutoPauseDetector(ActivityProfile.run);
      for (var i = 0; i < 120; i++) {
        expect(feed(d, i, speed: 0, northM: i * 2.5), AutoPauseChange.none);
      }
    });

    test('resumes by distance when no speed is reported', () {
      final d = AutoPauseDetector(ActivityProfile.walk);
      for (var i = 0; i <= 8; i++) {
        feed(d, i);
      }
      expect(d.isPaused, isTrue);
      expect(feed(d, 9, northM: 10), AutoPauseChange.none);
      expect(feed(d, 10, northM: 25), AutoPauseChange.resumed);
    });

    test('ignores inaccurate fixes and unsupported activities', () {
      final poor = AutoPauseDetector(ActivityProfile.run);
      for (var i = 0; i < 30; i++) {
        expect(feed(poor, i, accuracy: 60), AutoPauseChange.none);
      }
      final drive = AutoPauseDetector(ActivityProfile.drive);
      for (var i = 0; i < 30; i++) {
        expect(feed(drive, i), AutoPauseChange.none);
      }
      expect(AutoPauseDetector.supports(ActivityProfile.indoorPoor), isFalse);
    });
  });

  group('VoicePhrases', () {
    test('English kilometre split with average pace', () {
      expect(
        VoicePhrases.split(
          locale: AppLocale.english,
          units: Units.metric,
          profile: ActivityProfile.run,
          count: 3,
          elapsedMs: 1025000, // 17:05
          distanceM: 3000,
        ),
        '3 kilometres. Time: 17 minutes 5 seconds. '
        'Average pace: 5 minutes 42 seconds per kilometre.',
      );
    });

    test('singular units', () {
      final line = VoicePhrases.split(
        locale: AppLocale.english,
        units: Units.imperial,
        profile: ActivityProfile.run,
        count: 1,
        elapsedMs: 541000,
        distanceM: 1609.344,
      );
      expect(line, startsWith('1 mile. Time: 9 minutes 1 second.'));
      expect(line, endsWith('per mile.'));
    });

    test('Kiswahili split', () {
      expect(
        VoicePhrases.split(
          locale: AppLocale.swahili,
          units: Units.metric,
          profile: ActivityProfile.run,
          count: 2,
          elapsedMs: 720000,
          distanceM: 2000,
        ),
        'kilomita 2. Muda: dakika 12. Kasi ya wastani: dakika 6 kwa kilomita.',
      );
    });

    test('cycling reports speed, not pace', () {
      expect(
        VoicePhrases.split(
          locale: AppLocale.english,
          units: Units.metric,
          profile: ActivityProfile.cycle,
          count: 10,
          elapsedMs: 1800000,
          distanceM: 10000,
        ),
        contains('Average speed: 20 kilometres per hour'),
      );
    });

    test('durations', () {
      expect(VoicePhrases.duration(AppLocale.english, 0), '0 seconds');
      expect(VoicePhrases.duration(AppLocale.english, 3661000), '1 hour 1 minute 1 second');
      expect(VoicePhrases.duration(AppLocale.swahili, 3725000), 'saa 1 dakika 2 sekunde 5');
    });

    test('finish summary', () {
      expect(
        VoicePhrases.finished(
          locale: AppLocale.english,
          units: Units.metric,
          elapsedMs: 1860000,
          distanceM: 5210,
        ),
        'Finished. 5.21 kilometres in 31 minutes.',
      );
    });
  });

  group('keep-alive guide', () {
    test('recognises the makers that freeze background apps', () {
      expect(phoneFamilyOf('TECNO MOBILE LIMITED'), PhoneFamily.transsion);
      expect(phoneFamilyOf('INFINIX'), PhoneFamily.transsion);
      expect(phoneFamilyOf('itel'), PhoneFamily.transsion);
      expect(phoneFamilyOf('Xiaomi'), PhoneFamily.xiaomi);
      expect(phoneFamilyOf('samsung'), PhoneFamily.samsung);
      expect(phoneFamilyOf('realme'), PhoneFamily.oppo);
      expect(phoneFamilyOf('HONOR'), PhoneFamily.huawei);
      expect(phoneFamilyOf('Google'), PhoneFamily.other);
      expect(phoneFamilyOf(''), PhoneFamily.other);
    });

    test('every step has an English and a Kiswahili translation', () {
      for (final family in PhoneFamily.values) {
        final keys = keepAliveStepKeys(family);
        expect(keys.first, 'keep_step_unrestricted');
        for (final k in keys) {
          expect(L10n.hasKey(k), isTrue, reason: k);
          expect(L10n.tr(k, AppLocale.swahili), isNot(L10n.tr(k, AppLocale.english)), reason: k);
        }
      }
    });

    test('prompts only on aggressive phones that are still restricted', () {
      BatteryStatus s(String maker, {bool exempt = false, bool known = true}) => BatteryStatus(
          manufacturer: maker, ignoringBatteryOptimizations: exempt, known: known);
      expect(shouldPromptKeepAlive(s('tecno')), isTrue);
      expect(shouldPromptKeepAlive(s('tecno', exempt: true)), isFalse);
      expect(shouldPromptKeepAlive(s('google')), isFalse);
      expect(shouldPromptKeepAlive(s('tecno', known: false)), isFalse);
    });
  });
}
