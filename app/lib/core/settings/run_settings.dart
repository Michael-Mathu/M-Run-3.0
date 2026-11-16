import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences that change how a run is recorded and announced.
class RunSettings {
  /// Body weight, used only to estimate calories. Stays on the device.
  final double weightKg;

  /// Stop the clock automatically while standing still (traffic lights).
  final bool autoPause;

  /// Spoken distance / time / pace at every kilometre (or mile).
  final bool voiceCues;

  const RunSettings({
    this.weightKg = defaultWeightKg,
    this.autoPause = true,
    this.voiceCues = true,
  });

  static const double defaultWeightKg = 70;
  static const double minWeightKg = 30;
  static const double maxWeightKg = 200;

  RunSettings copyWith({double? weightKg, bool? autoPause, bool? voiceCues}) =>
      RunSettings(
        weightKg: weightKg ?? this.weightKg,
        autoPause: autoPause ?? this.autoPause,
        voiceCues: voiceCues ?? this.voiceCues,
      );
}

class RunSettingsNotifier extends Notifier<RunSettings> {
  static const _kWeight = 'run_weight_kg';
  static const _kAutoPause = 'run_auto_pause';
  static const _kVoice = 'run_voice_cues';

  @override
  RunSettings build() {
    _restore();
    return const RunSettings();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = RunSettings(
        weightKg: (prefs.getDouble(_kWeight) ?? RunSettings.defaultWeightKg)
            .clamp(RunSettings.minWeightKg, RunSettings.maxWeightKg),
        autoPause: prefs.getBool(_kAutoPause) ?? true,
        voiceCues: prefs.getBool(_kVoice) ?? true,
      );
    } catch (_) {
      // Keep the defaults (e.g. in tests without a prefs backend).
    }
  }

  Future<void> setWeightKg(double kg) async {
    final v = kg.clamp(RunSettings.minWeightKg, RunSettings.maxWeightKg).toDouble();
    state = state.copyWith(weightKg: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kWeight, v);
  }

  Future<void> setAutoPause(bool on) async {
    state = state.copyWith(autoPause: on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPause, on);
  }

  Future<void> setVoiceCues(bool on) async {
    state = state.copyWith(voiceCues: on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoice, on);
  }
}

final runSettingsProvider =
    NotifierProvider<RunSettingsNotifier, RunSettings>(RunSettingsNotifier.new);
