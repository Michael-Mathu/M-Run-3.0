import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/theme/shared_preferences_provider.dart';
import 'core/perf/frame_stats.dart';
import 'core/perf/glass_quality.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStats.install(); // no-op unless built with MWENDO_FRAME_STATS=true
  final prefs = await SharedPreferences.getInstance();
  GlassQuality.init(prefs); // adaptive glass blur (see glass_quality.dart)
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MwendoApp(),
    ),
  );
}