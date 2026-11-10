import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User choice for the translucent "glass" blur (Settings → Transparency).
enum GlassMode { auto, on, off }

/// Decides whether glass surfaces use a real backdrop blur.
///
/// The blur is the most expensive thing the app draws: measured on the
/// Android emulator it was ~35% of GPU time per scrolling frame and doubled
/// the number of dropped frames. Fast phones handle it easily, slow ones
/// don't — so in [GlassMode.auto] the app watches its own frame timings and,
/// if the GPU repeatedly can't keep up, switches glass to a solid frosted
/// tint (the iOS "Reduce Transparency" look) and remembers that for future
/// launches. [GlassMode.on] / [GlassMode.off] override the measurement.
///
/// Only rendering is affected; GPS tracking runs in a native foreground
/// service and the Dart pipeline doesn't depend on any of this.
class GlassQuality extends ChangeNotifier {
  GlassQuality._(this._prefs) {
    _mode = GlassMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_kModeKey),
      orElse: () => GlassMode.auto,
    );
    _slowDevice = _prefs.getBool(_kSlowKey) ?? false;
    if (_mode == GlassMode.auto && !_slowDevice) _startWatching();
  }

  static GlassQuality? _instance;

  /// Create once at startup (after SharedPreferences is ready).
  static GlassQuality init(SharedPreferences prefs) => _instance ??= GlassQuality._(prefs);

  /// The app-wide instance, or null in tests that never called [init].
  static GlassQuality? get instance => _instance;

  static const _kModeKey = 'glass_mode';
  static const _kSlowKey = 'glass_slow_device';

  final SharedPreferences _prefs;
  late GlassMode _mode;
  bool _slowDevice = false;

  GlassMode get mode => _mode;

  /// Whether glass should currently use a real backdrop blur.
  bool get blurEnabled => switch (_mode) {
        GlassMode.on => true,
        GlassMode.off => false,
        GlassMode.auto => !_slowDevice,
      };

  void setMode(GlassMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _prefs.setString(_kModeKey, mode.name);
    if (mode == GlassMode.auto) {
      // Re-measure from scratch when the user goes back to Auto.
      _slowDevice = false;
      _prefs.remove(_kSlowKey);
      _startWatching();
    } else {
      _stopWatching();
    }
    notifyListeners();
  }

  /// Cycles Auto → On → Off (for a simple Settings row).
  void cycle() => setMode(GlassMode.values[(_mode.index + 1) % GlassMode.values.length]);

  // ---- Auto measurement ------------------------------------------------------

  static const _windowFrames = 90;
  static const _budgetMs = 1000 / 60;
  static const _slowWindowsNeeded = 2;

  final List<double> _raster = [];
  int _slowWindows = 0;
  bool _watching = false;

  void _startWatching() {
    if (_watching) return;
    _watching = true;
    _raster.clear();
    _slowWindows = 0;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _stopWatching() {
    if (!_watching) return;
    _watching = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
    if (_raster.length < _windowFrames) return;
    _raster.sort();
    final p90 = _raster[(_raster.length * 0.9).floor()];
    final overBudget = _raster.where((ms) => ms > _budgetMs).length / _raster.length;
    _raster.clear();
    // "Slow" = the GPU misses the 60 Hz budget on more than a third of the
    // frames while the UI is animating, with a bad tail. Two such windows in a
    // row (≈3 s of interaction) before acting, so a one-off spike (map tiles
    // loading, first image decode) doesn't trigger it.
    if (overBudget > 0.33 && p90 > 24) {
      _slowWindows++;
    } else {
      _slowWindows = 0;
    }
    if (_slowWindows >= _slowWindowsNeeded) {
      _slowDevice = true;
      _prefs.setBool(_kSlowKey, true);
      _stopWatching();
      notifyListeners();
    }
  }
}

/// Makes [GlassQuality] available below it; dependents rebuild on change.
class GlassScope extends InheritedNotifier<GlassQuality> {
  const GlassScope({super.key, required GlassQuality super.notifier, required super.child});

  /// Whether glass at [context] should blur (true when no scope — tests).
  static bool blurOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.notifier?.blurEnabled ?? true;
}
