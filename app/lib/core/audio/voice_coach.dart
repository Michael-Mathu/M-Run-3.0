import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gps_pipeline/gps_pipeline.dart';

import '../../features/tracking/tracking_controller.dart';
import '../l10n/app_strings.dart';
import '../profile/profile_provider.dart';
import '../settings/run_settings.dart';

/// The spoken lines, kept free of any plugin so they can be unit-tested.
///
/// English and Kiswahili. Numbers are written as digits; the phone's
/// text-to-speech voice reads them in its own language.
class VoicePhrases {
  const VoicePhrases._();

  static bool _sw(AppLocale l) => l == AppLocale.swahili;

  static String started(AppLocale l) => _sw(l) ? 'Kurekodi kumeanza.' : 'Recording started.';

  static String paused(AppLocale l) => _sw(l) ? 'Imesitishwa.' : 'Paused.';

  static String autoPaused(AppLocale l) =>
      _sw(l) ? 'Imesitishwa kiotomatiki.' : 'Auto paused.';

  static String resumed(AppLocale l) => _sw(l) ? 'Inaendelea.' : 'Resumed.';

  /// "12 minutes 5 seconds" / "dakika 12 sekunde 5". Hours when needed.
  static String duration(AppLocale l, int ms) {
    final total = (ms / 1000).round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final parts = <String>[];
    if (_sw(l)) {
      if (h > 0) parts.add('saa $h');
      if (m > 0) parts.add('dakika $m');
      if (s > 0 || parts.isEmpty) parts.add('sekunde $s');
    } else {
      if (h > 0) parts.add('$h ${h == 1 ? 'hour' : 'hours'}');
      if (m > 0) parts.add('$m ${m == 1 ? 'minute' : 'minutes'}');
      if (s > 0 || parts.isEmpty) parts.add('$s ${s == 1 ? 'second' : 'seconds'}');
    }
    return parts.join(' ');
  }

  static String _unit(AppLocale l, Units u, {required bool plural}) {
    if (_sw(l)) return u == Units.imperial ? 'maili' : 'kilomita';
    if (u == Units.imperial) return plural ? 'miles' : 'mile';
    return plural ? 'kilometres' : 'kilometre';
  }

  /// Announcement at each whole kilometre (or mile).
  ///
  /// [count] whole units completed, [elapsedMs] time on the clock,
  /// [unitM] metres in one unit. Cycling reports speed instead of pace.
  static String split({
    required AppLocale locale,
    required Units units,
    required ActivityProfile profile,
    required int count,
    required int elapsedMs,
    required double distanceM,
  }) {
    final unitM = units == Units.imperial ? 1609.344 : 1000.0;
    final dist = _sw(locale)
        ? '${_unit(locale, units, plural: true)} $count'
        : '$count ${_unit(locale, units, plural: count != 1)}';
    final time = duration(locale, elapsedMs);
    final unitsDone = distanceM / unitM;
    if (unitsDone <= 0 || elapsedMs <= 0) {
      return _sw(locale) ? '$dist. Muda: $time.' : '$dist. Time: $time.';
    }
    final String rate;
    if (profile == ActivityProfile.cycle) {
      final perHour = (unitsDone / (elapsedMs / 3600000)).round();
      rate = _sw(locale)
          ? 'Kasi ya wastani: ${_unit(locale, units, plural: true)} $perHour kwa saa'
          : 'Average speed: $perHour ${_unit(locale, units, plural: true)} per hour';
    } else {
      final paceMs = (elapsedMs / unitsDone).round();
      rate = _sw(locale)
          ? 'Kasi ya wastani: ${duration(locale, paceMs)} kwa ${_unit(locale, units, plural: false)}'
          : 'Average pace: ${duration(locale, paceMs)} per ${_unit(locale, units, plural: false)}';
    }
    return _sw(locale) ? '$dist. Muda: $time. $rate.' : '$dist. Time: $time. $rate.';
  }

  /// Spoken summary when the activity ends.
  static String finished({
    required AppLocale locale,
    required Units units,
    required int elapsedMs,
    required double distanceM,
  }) {
    final unitM = units == Units.imperial ? 1609.344 : 1000.0;
    final d = (distanceM / unitM).toStringAsFixed(2);
    final time = duration(locale, elapsedMs);
    return _sw(locale)
        ? 'Umemaliza. ${_unit(locale, units, plural: true)} $d kwa $time.'
        : 'Finished. $d ${_unit(locale, units, plural: true)} in $time.';
  }
}

/// Speaks run updates through the phone's text-to-speech engine, so a runner
/// never has to look at the screen: start, pause / resume, and distance, time
/// and average pace at every kilometre (or mile).
///
/// Works with the screen off (the recording foreground service keeps the app
/// alive). Other audio is ducked while it speaks. If the phone has no voice
/// for Kiswahili it falls back to English lines with an English voice. Any
/// text-to-speech failure is swallowed: voice is never allowed to break a run.
class VoiceCoach {
  VoiceCoach(this._ref);

  final Ref _ref;
  FlutterTts? _tts;
  bool _initFailed = false;

  /// Language the engine is currently set to, and the locale lines are
  /// written in (English when the requested language has no voice).
  AppLocale? _engineLocale;

  int _lastUnit = 0;

  double get _unitM =>
      _ref.read(unitsProvider) == Units.imperial ? 1609.344 : 1000.0;

  bool get _enabled => _ref.read(runSettingsProvider).voiceCues;

  void onState(TrackingState? prev, TrackingState next) {
    if (prev == null) return;
    final was = prev.state;
    final now = next.state;
    final locale = _ref.read(localeProvider);

    final wasActive = was == AppEngineState.recording || was == AppEngineState.paused;

    if (now == AppEngineState.recording && !wasActive) {
      // New run, or an interrupted one picked up again.
      _lastUnit = (next.distanceM / _unitM).floor();
      _say((l) => VoicePhrases.started(l), locale);
      return;
    }
    if (was == AppEngineState.recording && now == AppEngineState.paused) {
      _say((l) => VoicePhrases.paused(l), locale);
      return;
    }
    if (was == AppEngineState.paused && now == AppEngineState.recording) {
      _say((l) => VoicePhrases.resumed(l), locale);
      return;
    }
    if (wasActive && now == AppEngineState.idle) {
      // Stopped and saved. (A run that failed to start has nothing to report.)
      if (next.gpsIssue != GpsIssue.startFailed && prev.distanceM >= 50) {
        final units = _ref.read(unitsProvider);
        _say(
          (l) => VoicePhrases.finished(
            locale: l,
            units: units,
            elapsedMs: prev.elapsedMs,
            distanceM: prev.distanceM,
          ),
          locale,
        );
      }
      _lastUnit = 0;
      return;
    }
    if (now != AppEngineState.recording) return;

    if (!prev.autoPaused && next.autoPaused) {
      _say((l) => VoicePhrases.autoPaused(l), locale);
      return;
    }
    if (prev.autoPaused && !next.autoPaused) {
      _say((l) => VoicePhrases.resumed(l), locale);
      return;
    }

    // Driving: a cue every kilometre would never stop talking.
    if (next.profile == ActivityProfile.drive) return;
    final done = (next.distanceM / _unitM).floor();
    if (done > _lastUnit) {
      _lastUnit = done;
      final units = _ref.read(unitsProvider);
      _say(
        (l) => VoicePhrases.split(
          locale: l,
          units: units,
          profile: next.profile,
          count: done,
          elapsedMs: next.elapsedMs,
          distanceM: next.distanceM,
        ),
        locale,
      );
    } else if (done < _lastUnit) {
      _lastUnit = done;
    }
  }

  /// Speaks a sample line (Settings → Voice cues), so the user hears the
  /// voice and volume before a run.
  Future<void> preview() {
    final locale = _ref.read(localeProvider);
    final units = _ref.read(unitsProvider);
    return _speak(
      (l) => VoicePhrases.split(
        locale: l,
        units: units,
        profile: ActivityProfile.run,
        count: 1,
        elapsedMs: 342000,
        distanceM: units == Units.imperial ? 1609.344 : 1000,
      ),
      locale,
    );
  }

  void _say(String Function(AppLocale) line, AppLocale locale) {
    if (!_enabled) return;
    _speak(line, locale);
  }

  Future<void> _speak(String Function(AppLocale) line, AppLocale locale) async {
    if (_initFailed) return;
    try {
      final tts = _tts ??= FlutterTts();
      if (_engineLocale == null || _requested != locale) {
        _requested = locale;
        _engineLocale = await _configure(tts, locale);
      }
      // focus: true asks Android for transient audio focus, so music ducks
      // while the cue is spoken.
      await tts.speak(line(_engineLocale!), focus: true);
    } catch (e) {
      // No text-to-speech engine, or the plugin is unavailable (tests).
      _initFailed = true;
      debugPrint('Voice cues unavailable: $e');
    }
  }

  AppLocale? _requested;

  Future<AppLocale> _configure(FlutterTts tts, AppLocale wanted) async {
    await tts.setSpeechRate(0.5);
    await tts.setQueueMode(1); // queue cues instead of cutting each other off
    if (wanted == AppLocale.swahili) {
      for (final tag in const ['sw-KE', 'sw-TZ', 'sw']) {
        if (await tts.isLanguageAvailable(tag) == true) {
          await tts.setLanguage(tag);
          return AppLocale.swahili;
        }
      }
    }
    await tts.setLanguage('en-US');
    return AppLocale.english;
  }

  void dispose() {
    try {
      _tts?.stop();
    } catch (_) {}
  }
}

/// Created once at app start (watched by the root widget) so cues play no
/// matter which screen is open.
final voiceCoachProvider = Provider<VoiceCoach>((ref) {
  final coach = VoiceCoach(ref);
  ref.listen<TrackingState>(trackingModelProvider, coach.onState);
  ref.onDispose(coach.dispose);
  return coach;
});
