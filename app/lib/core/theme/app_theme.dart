import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

/// Mwendo design system — v3 "Clarity" refresh (see docs/REVAMP_PLAN.md).
///
/// Follows Apple's Human Interface Guidelines / Liquid Glass principles on
/// both platforms: content first, one tint colour for actions, semantic
/// colours for state, the platform system font with tabular figures for every
/// number, neutral grouped surfaces, and translucent "glass" only on the
/// navigation layer (tab bar, floating controls, sheets).
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
  static const Color recording = Color(0xFFFF3B30); // live red (system red)
  static const Color sos = Color(0xFFFF3B30); // SOS / danger
  static const Color paused = Color(0xFFFF9500); // system orange
  static const Color idle = Color(0xFF8E8E93); // system grey
  static const Color achievement = dawn; // dawn gold

  // Highland green mapped to UI roles (success / data-viz / "ahead").
  static const Color flagGreen = Color(0xFF30D158); // system green (dark)
  static const Color flagGreenLight = Color(0xFF248A3D); // accessible green (light)
  static const Color flagRed = Color(0xFFFF3B30);

  // Semantic colors (success, warning, danger) — Apple system colours.
  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);

  /// Apple "secondary label" style text colours (60% / 30% of the ink).
  static const Color secondaryLabelLight = Color(0x993C3C43);
  static const Color secondaryLabelDark = Color(0x99EBEBF5);
  static const Color separatorLight = Color(0x4A3C3C43);
  static const Color separatorDark = Color(0x99545458);

  /// Glass tint for the navigation layer (tab bar, floating controls).
  static const Color glassLight = Color(0xCCF9F9F9);
  static const Color glassDark = Color(0xB31C1C1E);

  // Neutral grouped surfaces (Apple systemGroupedBackground family). The
  // warm "paper" tints competed with the content; neutral greys let the
  // route, the numbers and the single brand tint carry the screen.
  static const Color darkScaffold = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkElevated = Color(0xFF2C2C2E);

  static const Color lightScaffold = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFE5E5EA);

  static const Color onLight = Color(0xFF000000); // label
  static const Color onDark = Color(0xFFFFFFFF); // label (dark)

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

  // Radius scale (continuous-corner feel: grouped sections use r12, cards r16,
  // sheets/glass bars r24+, buttons are capsules).
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double rFull = 999;

  /// Minimum touch target (Apple HIG: 44 × 44 pt).
  static const double minTap = 44;

  /// Bottom padding a scrolling tab page needs so its last item clears the
  /// floating glass tab bar (the shell Scaffold uses `extendBody`, which puts
  /// the bar's height into the body's MediaQuery bottom padding).
  static double tabBarClearance(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + s24;

  // Motion — short, critically-damped, interruptible. No bouncy overshoot.
  static const Duration dFast = Duration(milliseconds: 150);
  static const Duration dMed = Duration(milliseconds: 280);
  static const Duration dSlow = Duration(milliseconds: 350);
  static const Curve curveSnappy = Curves.easeOutCubic;
  // Was Curves.elasticOut (toy-like wobble). A gentle overshoot reads as a
  // spring without the bounce.
  static const Curve curveSpring = Curves.easeOutBack;

  /// Durations collapse to zero when the user has Reduce Motion enabled.
  static Duration motion(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;

  // Elevation / shadow tokens. Content sits flat on grouped backgrounds (no
  // shadows); only floating navigation-layer elements get a soft, wide shadow.
  static const List<BoxShadow> elevation0 = [];
  static const List<BoxShadow> elevation1 = [];
  static const List<BoxShadow> elevation2 = [];
  /// Floating controls (glass buttons, tab bar).
  static const List<BoxShadow> elevation3 = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> elevation4 = [
    BoxShadow(color: Color(0x29000000), blurRadius: 30, offset: Offset(0, 10)),
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
  // The platform system font: SF Pro on iOS, Roboto on Android. It's already
  // on the device — the previous three Google Fonts were downloaded over the
  // network on first launch (slow on mobile data, text visibly re-flowed as
  // they arrived) and a condensed all-caps display face is hard to read at
  // arm's length mid-run. Every number uses tabular figures so digits don't
  // jitter as they tick.
  //
  // The three helpers keep their old names/signatures so existing call sites
  // re-skin without edits:
  //   displayFont — large titles & big metrics (heavy, slightly tight)
  //   bodyFont    — everything a runner reads
  //   monoFont    — data labels; now the system font with tabular figures
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Font family for a given size/weight. On Apple platforms this is null so
  /// the real system font (San Francisco) is used. Elsewhere the bundled
  /// Inter stands in for it: "InterDisplay" (tighter, like SF Pro Display)
  /// for bold text from 20 pt up, "Inter" (like SF Pro Text) for the rest.
  static String? fontFamilyFor(double size, FontWeight weight) {
    final apple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (apple) return null;
    return size >= 20 && weight.value >= 600 ? 'InterDisplay' : 'Inter';
  }

  static TextStyle displayFont({
    required double size,
    FontWeight weight = FontWeight.w700,
    double spacing = 0.3,
    double height = 1.0,
    Color? color,
  }) =>
      TextStyle(
        // The old condensed face was ~30% narrower; scale large sizes down a
        // touch so existing layouts (metric rows) don't overflow.
        fontSize: size >= 20 ? size * 0.88 : size,
        fontFamily: fontFamilyFor(size, weight),
        fontWeight: weight,
        // Apple tracks large text slightly tighter.
        letterSpacing: size >= 28 ? -0.5 : 0,
        height: height == 1.0 ? 1.1 : height,
        color: color,
        fontFeatures: _tabular,
      );

  static TextStyle bodyFont({
    required double size,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    double height = 1.4,
    Color? color,
  }) =>
      TextStyle(
        fontSize: size,
        fontFamily: fontFamilyFor(size, weight),
        fontWeight: weight,
        letterSpacing: spacing == 0 ? null : spacing.clamp(-0.5, 0.4),
        height: height,
        color: color,
      );

  static TextStyle monoFont({
    required double size,
    FontWeight weight = FontWeight.w500,
    double spacing = 0,
    Color? color,
  }) =>
      TextStyle(
        fontSize: size < 11 ? 11 : size,
        fontFamily: fontFamilyFor(size, weight),
        fontWeight: weight,
        letterSpacing: spacing.clamp(0, 0.6),
        color: color,
        fontFeatures: _tabular,
      );

  /// Apple-style type ramp (iOS default "Large" content size, in points).
  static TextTheme _text(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? onDark : onLight;
    TextStyle t(double size, FontWeight w, {double ls = 0, double h = 1.25}) =>
        TextStyle(
          fontSize: size,
          fontFamily: fontFamilyFor(size, w),
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: ink,
          // Tabular figures only on the big number styles: in Inter, 'tnum'
          // also widens punctuation, so "walk-run" read as "walk - run".
          fontFeatures: size >= 36 ? _tabular : null,
        );
    return TextTheme(
      displayLarge: t(48, FontWeight.w800, ls: -1.0, h: 1.05),
      displayMedium: t(40, FontWeight.w800, ls: -0.8, h: 1.05),
      displaySmall: t(36, FontWeight.w700, ls: -0.6, h: 1.1),
      headlineLarge: t(34, FontWeight.w700, ls: -0.6, h: 1.12), // Large Title
      headlineMedium: t(28, FontWeight.w700, ls: -0.4, h: 1.15), // Title 1
      headlineSmall: t(24, FontWeight.w700, ls: -0.3, h: 1.2),
      titleLarge: t(22, FontWeight.w700, ls: -0.3, h: 1.2), // Title 2
      titleMedium: t(17, FontWeight.w600, ls: -0.2, h: 1.3), // Headline
      titleSmall: t(15, FontWeight.w600, ls: -0.1, h: 1.3), // Subheadline
      bodyLarge: t(17, FontWeight.w400, ls: -0.2, h: 1.35), // Body
      bodyMedium: t(15, FontWeight.w400, ls: -0.1, h: 1.35), // Subheadline
      bodySmall: t(13, FontWeight.w400, h: 1.3), // Footnote
      labelLarge: t(15, FontWeight.w600, ls: -0.1), // buttons
      labelMedium: t(13, FontWeight.w600), // Footnote emphasised
      labelSmall: t(11, FontWeight.w600, ls: 0.3), // Caption 2 / eyebrows
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

  // Metric numbers: heavy system font with tabular figures (Apple Fitness
  // style) so "10.42 km" reads instantly and columns of digits line up.
  static TextStyle get _metricValue =>
      AppTheme.displayFont(size: 32, weight: FontWeight.w700);
  static TextStyle get _metricLabel =>
      AppTheme.monoFont(size: 12, weight: FontWeight.w600, spacing: 0.2, color: AppTheme.idle);
  static TextStyle get _displayMetric =>
      AppTheme.displayFont(size: 60, weight: FontWeight.w800);
  static TextStyle get _heroMetric =>
      AppTheme.displayFont(size: 46, weight: FontWeight.w800);
  static TextStyle get _title =>
      AppTheme.bodyFont(size: 22, weight: FontWeight.w700, height: 1.2);
  static TextStyle get _subtitle => AppTheme.bodyFont(size: 15);
  static TextStyle get _body => AppTheme.bodyFont(size: 17);
  static TextStyle get _caption =>
      AppTheme.bodyFont(size: 13, weight: FontWeight.w500);
  static TextStyle get _label => AppTheme.bodyFont(size: 15, weight: FontWeight.w600);

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
        danger = AppTheme.danger,
        warning = AppTheme.warning,
        success = AppTheme.success,
        achievement = AppTheme.dawn,
        idle = AppTheme.idle,
        recording = AppTheme.recording,
        paused = AppTheme.paused,
        sos = AppTheme.sos,
        flagGreen = AppTheme.flagGreen,
        flagGreenLight = AppTheme.flagGreenLight,
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
        danger = AppTheme.danger,
        warning = AppTheme.warning,
        success = AppTheme.success,
        achievement = const Color(0xFFFFD15C),
        idle = AppTheme.idle,
        recording = AppTheme.recording,
        paused = AppTheme.paused,
        sos = AppTheme.sos,
        flagGreen = AppTheme.flagGreen,
        flagGreenLight = AppTheme.flagGreenLight,
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
        danger = AppTheme.danger,
        warning = AppTheme.warning,
        success = AppTheme.success,
        achievement = const Color(0xFFFFD15C),
        idle = AppTheme.idle,
        recording = AppTheme.recording,
        paused = AppTheme.paused,
        sos = AppTheme.sos,
        flagGreen = AppTheme.flagGreen,
        flagGreenLight = AppTheme.flagGreenLight,
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
        danger = AppTheme.danger,
        warning = AppTheme.warning,
        success = AppTheme.success,
        achievement = const Color(0xFFFFD15C),
        idle = AppTheme.idle,
        recording = AppTheme.recording,
        paused = AppTheme.paused,
        sos = AppTheme.sos,
        flagGreen = AppTheme.flagGreen,
        flagGreenLight = AppTheme.flagGreenLight,
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
        danger = AppTheme.danger,
        warning = AppTheme.warning,
        success = AppTheme.success,
        achievement = const Color(0xFFFFD15C),
        idle = AppTheme.idle,
        recording = AppTheme.recording,
        paused = AppTheme.paused,
        sos = AppTheme.sos,
        flagGreen = AppTheme.flagGreen,
        flagGreenLight = AppTheme.flagGreenLight,
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
  // On black, the brand tint is lifted a little so it keeps contrast.
  final primary = isDark
      ? Color.lerp(palette.primary, Colors.white, 0.18)!
      : palette.primary;
  final ink = isDark ? AppTheme.onDark : AppTheme.onLight;
  final secondaryInk =
      isDark ? AppTheme.secondaryLabelDark : AppTheme.secondaryLabelLight;
  final card = isDark ? AppTheme.darkCard : AppTheme.lightCard;
  final elevated = isDark ? AppTheme.darkElevated : AppTheme.lightElevated;
  final scaffold = isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold;
  final separator = isDark ? AppTheme.separatorDark : AppTheme.separatorLight;

  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primary.withValues(alpha: isDark ? 0.28 : 0.14),
    onPrimaryContainer: isDark ? Colors.white : palette.primary,
    secondary: palette.secondary,
    secondaryContainer: palette.secondaryContainer,
    // secondaryContainer is a light tint in every preset, so its text must be
    // dark ink in both themes.
    onSecondaryContainer: AppTheme.onLight,
    error: palette.danger,
    onError: Colors.white,
    surface: card,
    onSurface: ink,
    onSurfaceVariant: secondaryInk,
    surfaceContainerLowest: scaffold,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: elevated,
    surfaceContainerHighest: elevated,
    outline: separator,
    outlineVariant: separator,
    surfaceTint: Colors.transparent,
  );

  final extensions = AppExtensions.fromPalette(palette, brightness);
  final text = AppTheme._text(brightness);
  const capsule = StadiumBorder();
  final buttonText = AppTheme.bodyFont(size: 17, weight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    // Behave like iOS on every platform: bouncing scroll physics, iOS
    // navigation bars and back chevrons, Cupertino switches/dialogs/pickers
    // from the adaptive constructors, iOS text-selection handles.
    platform: TargetPlatform.iOS,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    canvasColor: scaffold,
    textTheme: text,
    // No Material ink ripples — a quiet press highlight instead (iOS-style
    // "dim on press").
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: ink.withValues(alpha: 0.06),
    hoverColor: ink.withValues(alpha: 0.04),
    // Native push with edge swipe-back on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
    // Adaptive widgets (Switch.adaptive, AlertDialog.adaptive, ...) pick this up.
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: scaffold,
      barBackgroundColor: isDark ? AppTheme.glassDark : AppTheme.glassLight,
      textTheme: CupertinoTextThemeData(
        primaryColor: primary,
        textStyle: AppTheme.bodyFont(size: 17, color: ink),
        navTitleTextStyle:
            AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: ink),
        navLargeTitleTextStyle: TextStyle(
          fontSize: 34,
          fontFamily: AppTheme.fontFamilyFor(34, FontWeight.w700),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
          color: ink,
        ),
        navActionTextStyle: AppTheme.bodyFont(size: 17, color: primary),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleMedium,
      iconTheme: IconThemeData(color: primary, size: 24),
      actionsIconTheme: IconThemeData(color: primary, size: 24),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.r16)),
      margin: EdgeInsets.zero,
    ),
    iconTheme: IconThemeData(size: 24, color: ink),
    dividerTheme: DividerThemeData(color: separator, thickness: 0.5, space: 0.5),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: primary,
      textColor: ink,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(color: secondaryInk),
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.s16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(AppTheme.minTap, 50),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s24, vertical: AppTheme.s14),
        shape: capsule,
        elevation: 0,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(AppTheme.minTap, 50),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s24, vertical: AppTheme.s14),
        shape: capsule,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      // "Tinted" button: tint-coloured label on a soft tint fill, no outline.
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: primary.withValues(alpha: isDark ? 0.22 : 0.12),
        side: BorderSide.none,
        minimumSize: const Size(AppTheme.minTap, 50),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s24, vertical: AppTheme.s14),
        shape: capsule,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(AppTheme.minTap, AppTheme.minTap),
        shape: capsule,
        textStyle: AppTheme.bodyFont(size: 17, weight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(AppTheme.minTap, AppTheme.minTap),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: capsule,
      extendedTextStyle: buttonText,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      // iOS segmented-control look: grey track, raised selected segment.
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? card : elevated),
        foregroundColor: WidgetStateProperty.all(ink),
        side: WidgetStateProperty.all(BorderSide(color: elevated, width: 2)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
        textStyle: WidgetStateProperty.all(
            AppTheme.bodyFont(size: 13, weight: FontWeight.w600)),
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: elevated,
      selectedColor: primary,
      secondarySelectedColor: primary,
      labelStyle: AppTheme.bodyFont(size: 15, weight: FontWeight.w500, color: ink),
      secondaryLabelStyle:
          AppTheme.bodyFont(size: 15, weight: FontWeight.w600, color: Colors.white),
      side: BorderSide.none,
      shape: capsule,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s4),
    ),
    switchTheme: SwitchThemeData(
      // iOS switch colours: green track when on.
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppTheme.success : elevated),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: elevated,
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: elevated,
      thumbColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppTheme.darkElevated : AppTheme.lightCard,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.r12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.r12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.r12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: secondaryInk),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    // Floating, rounded "toast" instead of a full-width Material snackbar.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppTheme.darkElevated : const Color(0xF21C1C1E),
      contentTextStyle:
          AppTheme.bodyFont(size: 15, weight: FontWeight.w500, color: Colors.white),
      actionTextColor:
          isDark ? primary : Color.lerp(palette.primary, Colors.white, 0.35),
      elevation: 0,
      insetPadding:
          const EdgeInsets.fromLTRB(AppTheme.s16, 0, AppTheme.s16, AppTheme.s24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.r16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppTheme.darkElevated : AppTheme.lightCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.r24)),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightScaffold,
      modalBackgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightScaffold,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: separator,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : const Color(0xF21C1C1E),
        borderRadius: BorderRadius.circular(AppTheme.r8),
      ),
      textStyle: AppTheme.bodyFont(size: 13, color: Colors.white),
    ),
    extensions: [extensions],
  );
}
