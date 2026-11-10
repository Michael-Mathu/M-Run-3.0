import 'package:flutter/material.dart';
import 'package:mwendo_app/core/perf/glass_quality.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/router/app_router.dart';

class MwendoApp extends ConsumerWidget {
  const MwendoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final palette = ref.watch(paletteProvider);
    return MaterialApp.router(
      title: 'Mwendo — Track Every Step',
      theme: buildTheme(palette, Brightness.light),
      darkTheme: buildTheme(palette, Brightness.dark),
      themeMode: mode,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
      // One shared backdrop for every grouped glass blur on screen (tab bar,
      // floating panels), so the engine snapshots the background once per
      // frame instead of once per blurred element.
      builder: (context, child) {
        Widget app = BackdropGroup(child: child ?? const SizedBox.shrink());
        final glass = GlassQuality.instance;
        if (glass != null) app = GlassScope(notifier: glass, child: app);
        return app;
      },
    );
  }
}