import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mwendo design system.
/// Opinionated, athletic, high-contrast — built to hold a candle to Strava / NRC.
class AppTheme {
  // ---- "Red Earth" palette ----------------------------------------------
  // Drawn from the material the app is actually about: the laterite roads of
  // Iten, Rift Valley dawn light, and the discipline of a stopwatch. One
  // accent (Earth) does action; a second (Dawn) means "you earned this"; a
  // third (Highland) means "you're clear / ahead". See AUDIT_2 redesign.
  static const Color earth = Color(0xFFB14A2A); // primary accent
  static const Color earthDeep = Color(0xFF8C3A20);
  static const Color dawn = Color(0xFFD89A2E); // achievement / highlight
  static const Color highland = Color(0xFF3C8368); // success / "ahead" (dark)
  static const Color highlandLight = Color(0xFF2C6B54); // success (light, deeper)

  // `brand`/`brandSoft` keep their names (referenced widely) but now point at
  // Earth, so every existing accent site re-skins for free.
  static const Color brand = earth;
  static const Color brandSoft = Color(0xFFD6714E);
  // Live/alert red — a warm flag red that harmonises with the earth accent.
  static const Color recording = Color(0xFFC5283D); // live red pulse
  static const Color sos = Color(0xFFC5283D); // SOS / danger
  static const Color paused = dawn; // amber pause
  static const Color idle = Color(0xFF8A8078); // warm neutral grey
  static const Color achievement = dawn; // dawn gold

  // Highland green mapped to UI roles (success / data-viz / "ahead").
  static const Color flagGreen = highland; // dark-theme green
  static const Color flagGreenLight = highlandLight; // light-theme green
  static const Color flagRed = Color(0xFFC5283D);

  // Semantic colors (success, warning, danger)
  static const Color success = highlandLight;
  static const Color danger = Color(0xFFC5283D);
  static const Color warning = dawn;

  // Warm-ink dark surfaces (not pure black)
  static const Color darkScaffold = Color(0xFF17110C);
  static const Color darkCard = Color(0xFF221A13);
  static const Color darkElevated = Color(0xFF2C2219);

  // Unbleached "paper" light surfaces (warm, not clinical white)
  static const Color lightScaffold = Color(0xFFF7F1E8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF0E7D8);

  // Warm text colors, replacing the old cool near-black.
  static const Color onLight = Color(0xFF211A14); // ink on paper
  static const Color onDark = Color(0xFFF3E9DC); // cream on ink

  // Spacing scale (4pt grid)
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s48 = 48;

  // Radius scale
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double rFull = 999;

  // Motion
  static const Duration dFast = Duration(milliseconds: 150);
  static const Duration dMed = Duration(milliseconds: 300);
  static const Duration dSlow = Duration(milliseconds: 520);
  static const Curve curveSnappy = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;

  // Elevation / shadow tokens
  static const List<BoxShadow> elevation0 = [];
  static const List<BoxShadow> elevation1 = [
    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
  ];
  /// Elevation tokens for shadows and depth.
  static const List<BoxShadow> elevation3 = [
    BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elevation4 = [
    BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Icon container sizes
  static const double iconContainerSm = 40;
  static const double iconContainerMd = 48;
  static const double iconContainerLg = 56;
  static const double iconContainerXl = 64;

  // Avatar sizes
  static const double avatarXs = 24;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
  static const double avatarXl = 68;

  // Navigation bar height
  static const double navBarHeight = 72;

  // Heart-rate zone ramp (1..5): gray -> blue -> green -> orange -> red
  static const List<Color> hrZones = [
    Color(0xFF9AA0A6),
    Color(0xFF4A90E2),
    Color(0xFF2BB673),
    Color(0xFFFFA726),
    Color(0xFFFE2E4B),
  ];

  // Challenge tiers
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFFC0C6CC);
  static const Color tierGold = dawn; // dawn gold — also the streak color
  static const Color tierPlatinum = Color(0xFF6FB6A0); // highland-tinted platinum

  /// Named-tier → color lookup so challenge cards can be visually distinct
  /// without each site hand-coding the mapping.
  static const Map<String, Color> tierColors = {
    'bronze': tierBronze,
    'silver': tierSilver,
    'gold': tierGold,
    'platinum': tierPlatinum,
  };

  // Dawn gradient: sunrise gold folding into red earth — used sparingly on
  // hero moments (weekly card, logo tile, first-run CTA).
  static LinearGradient get brandGradient => const LinearGradient(
        colors: [dawn, earth],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ---- Type system -------------------------------------------------------
  // Big Shoulders Display — condensed, athletic, "stadium scoreboard". Carries
  // display/headline/large-title sizes and the big metric numbers.
  // Work Sans — every sentence a runner actually reads.
  // IBM Plex Mono — reserved for data: pace, distance, splits, eyebrow labels.
  static TextStyle displayFont({
    required double size,
    FontWeight weight = FontWeight.w700,
    double spacing = 0.3,
    double height = 1.0,
    Color? color,
  }) =>
      GoogleFonts.bigShouldersDisplay(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: color,
      );

  static TextStyle bodyFont({
    required double size,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    double height = 1.4,
    Color? color,
  }) =>
      GoogleFonts.workSans(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: color,
      );

  static TextStyle monoFont({
    required double size,
    FontWeight weight = FontWeight.w500,
    double spacing = 0,
    Color? color,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextTheme _text(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? onDark : onLight;
    return TextTheme(
      // Display + headline + large titles: Big Shoulders (condensed athletic).
      displayLarge: displayFont(size: 56, weight: FontWeight.w800, color: ink),
      displayMedium: displayFont(size: 44, weight: FontWeight.w800, color: ink),
      headlineLarge: displayFont(size: 34, weight: FontWeight.w700, color: ink),
      headlineMedium: displayFont(size: 28, weight: FontWeight.w700, color: ink),
      titleLarge: displayFont(size: 22, weight: FontWeight.w700, color: ink),
      // Small titles + body + labels: Work Sans (readable at text sizes).
      titleMedium: bodyFont(size: 16, weight: FontWeight.w600, color: ink),
      bodyLarge: bodyFont(size: 16, color: ink),
      bodyMedium: bodyFont(size: 14, color: ink),
      labelLarge: bodyFont(size: 14, weight: FontWeight.w600, color: ink),
      labelMedium: bodyFont(size: 12, weight: FontWeight.w600, spacing: 0.4, color: ink),
      // Tiny eyebrow labels: mono, uppercase, tracked.
      labelSmall: monoFont(size: 10, weight: FontWeight.w600, spacing: 1.4, color: ink),
    );
  }

  // The app builds its theme exclusively through [buildTheme] (see app.dart),
  // so the old static `light`/`dark` ThemeData blocks were removed. Keeping a
  // single construction path avoids two definitions drifting apart.
}

/// App-specific semantic tokens passed through the theme tree.
class AppExtensions extends ThemeExtension<AppExtensions> {
  final Color recording;
  final Color paused;
  final Color idle;
  final Color sos;
  final Color achievement;
  final List<Color> hrZones;
  final LinearGradient brandGradient;
  final Color flagGreen;
  final Color success;
  final Color warning;
  final Color danger;
  final TextStyle metricValue;
  final TextStyle metricLabel;
  final TextStyle displayMetric;
  final TextStyle heroMetric;
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle label;

  const AppExtensions({
    required this.recording,
    required this.paused,
    required this.idle,
    required this.sos,
    required this.achievement,
    required this.hrZones,
    required this.brandGradient,
    required this.flagGreen,
    required this.success,
    required this.warning,
    required this.danger,
    required this.metricValue,
    required this.metricLabel,
    required this.displayMetric,
    required this.heroMetric,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.caption,
    required this.label,
  });

  // Metric numbers ride the display face (Big Shoulders) with tabular figures
  // so a "10.42 km" reads like a scoreboard and columns of digits align.
  static TextStyle get _metricValue =>
      AppTheme.displayFont(size: 32, weight: FontWeight.w700, spacing: 0.2);
  static TextStyle get _metricLabel =>
      AppTheme.monoFont(size: 10, weight: FontWeight.w600, spacing: 1.2, color: AppTheme.idle);
  static TextStyle get _displayMetric =>
      AppTheme.displayFont(size: 60, weight: FontWeight.w800, spacing: 0.3);
  static TextStyle get _heroMetric =>
      AppTheme.displayFont(size: 46, weight: FontWeight.w800, spacing: 0.3);
  static TextStyle get _title => AppTheme.displayFont(size: 22, weight: FontWeight.w700);
  static TextStyle get _subtitle => AppTheme.bodyFont(size: 14);
  static TextStyle get _body => AppTheme.bodyFont(size: 16);
  static TextStyle get _caption =>
      AppTheme.bodyFont(size: 12, weight: FontWeight.w600, spacing: 0.4);
  static TextStyle get _label => AppTheme.bodyFont(size: 14, weight: FontWeight.w600);

  @override
  AppExtensions copyWith({
    Color? recording,
    Color? paused,
    Color? idle,
    Color? sos,
    Color? achievement,
    List<Color>? hrZones,
    LinearGradient? brandGradient,
    Color? flagGreen,
    Color? success,
    Color? warning,
    Color? danger,
    TextStyle? metricValue,
    TextStyle? metricLabel,
    TextStyle? displayMetric,
    TextStyle? heroMetric,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? label,
  }) =>
      AppExtensions(
        recording: recording ?? this.recording,
        paused: paused ?? this.paused,
        idle: idle ?? this.idle,
        sos: sos ?? this.sos,
        achievement: achievement ?? this.achievement,
        hrZones: hrZones ?? this.hrZones,
        brandGradient: brandGradient ?? this.brandGradient,
        flagGreen: flagGreen ?? this.flagGreen,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        metricValue: metricValue ?? this.metricValue,
        metricLabel: metricLabel ?? this.metricLabel,
        displayMetric: displayMetric ?? this.displayMetric,
        heroMetric: heroMetric ?? this.heroMetric,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        body: body ?? this.body,
        caption: caption ?? this.caption,
        label: label ?? this.label,
);

  static AppExtensions fromPalette(ColorPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppExtensions(
      recording: palette.recording,
      paused: palette.paused,
      idle: palette.idle,
      sos: palette.sos,
      achievement: palette.achievement,
      hrZones: AppTheme.hrZones,
      brandGradient: LinearGradient(
        colors: [palette.primary, palette.gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      flagGreen: isDark ? palette.flagGreen : palette.flagGreenLight,
      success: palette.success,
      warning: palette.warning,
      danger: palette.danger,
      metricValue: _metricValue,
      metricLabel: _metricLabel,
      displayMetric: _displayMetric,
      heroMetric: _heroMetric,
      title: _title,
      subtitle: _subtitle,
      body: _body,
      caption: _caption,
      label: _label,
    );
  }

  @override
  AppExtensions lerp(ThemeExtension<AppExtensions>? other, double t) {
    if (other is! AppExtensions) return this;
    return AppExtensions(
      recording: Color.lerp(recording, other.recording, t)!,
      paused: Color.lerp(paused, other.paused, t)!,
      idle: Color.lerp(idle, other.idle, t)!,
      sos: Color.lerp(sos, other.sos, t)!,
      achievement: Color.lerp(achievement, other.achievement, t)!,
      hrZones: hrZones,
      brandGradient: brandGradient,
      flagGreen: Color.lerp(flagGreen, other.flagGreen, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      metricValue: TextStyle.lerp(metricValue, other.metricValue, t)!,
      metricLabel: TextStyle.lerp(metricLabel, other.metricLabel, t)!,
      displayMetric: TextStyle.lerp(displayMetric, other.displayMetric, t)!,
      heroMetric: TextStyle.lerp(heroMetric, other.heroMetric, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
    );
  }
}

extension AppContext on BuildContext {
  AppExtensions get tokens => Theme.of(this).extension<AppExtensions>()!;
  /// Shorthand alias for [tokens] (theme-aware colors in widgets).
  AppExtensions get cs => tokens;
}

/// Motion vocabulary — use these tokens instead of hardcoded durations.
///   dFast (150ms) — micro-interactions, ticks
///   dMed  (300ms) — state changes, content fades
///   dSlow (520ms) — entrance/staggered reveals
///   curveSnappy — UI state changes (easeOutCubic)
///   curveSpring — playful/overshoot (trophy pop, first-run hint)
///
/// Haptic intent map:
///   selection — passive UI nav (tab switch)
///   light     — affirmative confirmation
///   medium    — state-changing action (start run)
///   heavy     — destructive/significant (stop run)
///   celebrate — level-up / achievement
// ponytail: motion/haptic doc kept as comments to avoid an unused-symbol lint.

/// Immutable color palette definition for a theme variant.
/// All colors are opaque (alpha = 1.0) unless explicitly noted.
/// Use this to define new curated themes (e.g. Kinetic Orange, Kenyan Green, Midnight Blue, Berry).
@immutable
class ColorPalette {
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color gradientEnd;
  final Color danger;
  final Color warning;
  final Color success;
  final Color achievement;
  final Color idle;
  final Color recording;
  final Color paused;
  final Color sos;
  final Color flagGreen;
  final Color flagGreenLight;
  final Color tierBronze;
  final Color tierSilver;
  final Color tierGold;
  final Color tierPlatinum;

  const ColorPalette({
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.gradientEnd,
    required this.danger,
    required this.warning,
    required this.success,
    required this.achievement,
    required this.idle,
    required this.recording,
    required this.paused,
    required this.sos,
    required this.flagGreen,
    required this.flagGreenLight,
    required this.tierBronze,
    required this.tierSilver,
    required this.tierGold,
    required this.tierPlatinum,
  });

  /// "Red Earth" — the default identity. Earth accent, dawn achievement,
  /// highland success. See the AUDIT_2 redesign proposal.
  const ColorPalette.redEarth()
      : primary = AppTheme.earth,
        primaryContainer = const Color(0xFFD6714E),
        secondary = AppTheme.dawn,
        secondaryContainer = const Color(0xFFF5E4BC),
        gradientEnd = AppTheme.dawn,
        danger = const Color(0xFFC5283D),
        warning = AppTheme.dawn,
        success = AppTheme.highlandLight,
        achievement = AppTheme.dawn,
        idle = const Color(0xFF8A8078),
        recording = const Color(0xFFC5283D),
        paused = AppTheme.dawn,
        sos = const Color(0xFFC5283D),
        flagGreen = AppTheme.highland,
        flagGreenLight = AppTheme.highlandLight,
        tierBronze = const Color(0xFFCD7F32),
        tierSilver = const Color(0xFFC0C6CC),
        tierGold = AppTheme.dawn,
        tierPlatinum = const Color(0xFF6FB6A0);

  /// Kinetic Orange theme (the previous brand — kept as an alternative).
  const ColorPalette.orange()
      : primary = const Color(0xFFFF5A1F),
        primaryContainer = const Color(0xFFFF8A3D),
        secondary = const Color(0xFFFFD15C),
        secondaryContainer = const Color(0xFFFFE8A0),
        gradientEnd = const Color(0xFFFF8A3D),
        danger = const Color(0xFFC5283D),
        warning = const Color(0xFFF5A623),
        success = const Color(0xFF0E5C36),
        achievement = const Color(0xFFFFD15C),
        idle = const Color(0xFF8A8A8E),
        recording = const Color(0xFFC5283D),
        paused = const Color(0xFFF5A623),
        sos = const Color(0xFFC5283D),
        flagGreen = const Color(0xFF1B8A5A),
        flagGreenLight = const Color(0xFF0E5C36),
        tierBronze = const Color(0xFFCD7F32),
        tierSilver = const Color(0xFFC0C6CC),
        tierGold = const Color(0xFFFFD15C),
        tierPlatinum = const Color(0xFF7FE7E0);

  /// Kenyan Green theme (flag-inspired).
  const ColorPalette.forest()
      : primary = const Color(0xFF1B8A5A),
        primaryContainer = const Color(0xFF2FD17A),
        secondary = const Color(0xFFFFD15C),
        secondaryContainer = const Color(0xFFFFE8A0),
        gradientEnd = const Color(0xFF2FD17A),
        danger = const Color(0xFFC5283D),
        warning = const Color(0xFFF5A623),
        success = const Color(0xFF0E5C36),
        achievement = const Color(0xFFFFD15C),
        idle = const Color(0xFF8A8A8E),
        recording = const Color(0xFFC5283D),
        paused = const Color(0xFFF5A623),
        sos = const Color(0xFFC5283D),
        flagGreen = const Color(0xFF1B8A5A),
        flagGreenLight = const Color(0xFF0E5C36),
        tierBronze = const Color(0xFFCD7F32),
        tierSilver = const Color(0xFFC0C6CC),
        tierGold = const Color(0xFFFFD15C),
        tierPlatinum = const Color(0xFF7FE7E0);

  /// Midnight Blue theme.
  const ColorPalette.ocean()
      : primary = const Color(0xFF4A90E2),
        primaryContainer = const Color(0xFF6BB3F0),
        secondary = const Color(0xFFFFD15C),
        secondaryContainer = const Color(0xFFFFE8A0),
        gradientEnd = const Color(0xFF6BB3F0),
        danger = const Color(0xFFC5283D),
        warning = const Color(0xFFF5A623),
        success = const Color(0xFF0E5C36),
        achievement = const Color(0xFFFFD15C),
        idle = const Color(0xFF8A8A8E),
        recording = const Color(0xFFC5283D),
        paused = const Color(0xFFF5A623),
        sos = const Color(0xFFC5283D),
        flagGreen = const Color(0xFF1B8A5A),
        flagGreenLight = const Color(0xFF0E5C36),
        tierBronze = const Color(0xFFCD7F32),
        tierSilver = const Color(0xFFC0C6CC),
        tierGold = const Color(0xFFFFD15C),
        tierPlatinum = const Color(0xFF7FE7E0);

  /// Berry / Magenta theme.
  const ColorPalette.berry()
      : primary = const Color(0xFFD02D7A),
        primaryContainer = const Color(0xFFFF5DA2),
        secondary = const Color(0xFFFFD15C),
        secondaryContainer = const Color(0xFFFFE8A0),
        gradientEnd = const Color(0xFFFF5DA2),
        danger = const Color(0xFFC5283D),
        warning = const Color(0xFFF5A623),
        success = const Color(0xFF0E5C36),
        achievement = const Color(0xFFFFD15C),
        idle = const Color(0xFF8A8A8E),
        recording = const Color(0xFFC5283D),
        paused = const Color(0xFFF5A623),
        sos = const Color(0xFFC5283D),
        flagGreen = const Color(0xFF1B8A5A),
        flagGreenLight = const Color(0xFF0E5C36),
        tierBronze = const Color(0xFFCD7F32),
        tierSilver = const Color(0xFFC0C6CC),
        tierGold = const Color(0xFFFFD15C),
        tierPlatinum = const Color(0xFF7FE7E0);

  /// All available palette presets. Red Earth leads as the default identity.
  static const List<ColorPalette> presets = [
    ColorPalette.redEarth(),
    ColorPalette.orange(),
    ColorPalette.forest(),
    ColorPalette.ocean(),
    ColorPalette.berry(),
  ];

  /// Map from preset name to palette for persistence.
  static const Map<String, ColorPalette> presetsByName = {
    'redEarth': ColorPalette.redEarth(),
    'orange': ColorPalette.orange(),
    'forest': ColorPalette.forest(),
    'ocean': ColorPalette.ocean(),
    'berry': ColorPalette.berry(),
  };
}

/// Builds a [ThemeData] from a [ColorPalette] and brightness.
/// This is the single source of truth for theme construction.
ThemeData buildTheme(ColorPalette palette, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final seedColor = palette.primary;

  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  ).copyWith(
    primary: palette.primary,
    primaryContainer: palette.primaryContainer,
    secondary: palette.secondary,
    secondaryContainer: palette.secondaryContainer,
    error: palette.danger,
    onError: Colors.white,
    surface: isDark ? AppTheme.darkCard : AppTheme.lightCard,
    onSurface: isDark ? AppTheme.onDark : AppTheme.onLight,
    surfaceContainerHighest: isDark ? AppTheme.darkElevated : AppTheme.lightElevated,
  );

  final extensions = AppExtensions.fromPalette(palette, brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
    textTheme: AppTheme._text(brightness),
    cardTheme: CardThemeData(
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.r16)),
      margin: EdgeInsets.zero,
    ),
    iconTheme: const IconThemeData(size: 24, fill: 1, weight: 600),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s24, vertical: AppTheme.s16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.r12)),
        // Big Shoulders on buttons: the label reads like a start line.
        textStyle: AppTheme.displayFont(size: 17, weight: FontWeight.w700, spacing: 0.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s24, vertical: AppTheme.s16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.r12)),
        textStyle: AppTheme.displayFont(size: 17, weight: FontWeight.w700, spacing: 0.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      indicatorColor: palette.primary.withValues(alpha: isDark ? 0.20 : 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppTheme.darkElevated : AppTheme.onLight,
      contentTextStyle: TextStyle(color: isDark ? AppTheme.onDark : AppTheme.lightScaffold),
      actionTextColor: palette.secondary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppTheme.darkElevated : AppTheme.lightCard,
    ),
    extensions: [extensions],
  );
}
