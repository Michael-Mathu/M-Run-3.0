import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mwendo_app/core/perf/glass_quality.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';

/// Translucent "Liquid Glass" surface for the navigation layer only: tab bar,
/// floating map controls, run controls. Never use it for content cards.
///
/// Falls back to a solid surface when the user asks for high contrast (the
/// closest signal Flutter exposes to iOS "Reduce Transparency"), following
/// iOS 27's legibility-first revision of Liquid Glass.
///
/// Performance: the blur is the most expensive thing the app draws (it runs
/// on every frame anything moves). So: blurs share one backdrop snapshot via
/// the app-level [BackdropGroup]; [shadow] is off by default (a blurred
/// shadow under a blur doubled the cost and was invisible on dark
/// backgrounds); and `blur: 0` skips the filter entirely with a denser tint —
/// use it for glass that floats over the live map, where a backdrop blur on
/// top of a native map view is especially costly on Android.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final bool shadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppTheme.r24)),
    this.padding,
    this.blur = 24,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.maybeHighContrastOf(context) == true;
    final blurred = !solid && blur > 0 && GlassScope.blurOf(context);
    final tint = solid
        ? (dark ? AppTheme.darkElevated : AppTheme.lightCard)
        : blurred
            ? (dark ? AppTheme.glassDark : AppTheme.glassLight)
            // No blur: a denser tint keeps text legible over busy maps.
            : (dark ? const Color(0xE61C1C1E) : const Color(0xF2F9F9F9));
    final edge = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.65);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
        border: Border.all(color: edge, width: 0.75),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (blurred) {
      body = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      );
    }
    if (!shadow) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppTheme.elevation3,
      ),
      child: body,
    );
  }
}

/// Round glass button for floating controls over maps.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color? color;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(size / 2),
        // Floats over a map: no backdrop blur, small shadow for separation.
        blur: 0,
        shadow: true,
        child: SizedBox(
          width: size,
          height: size,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon,
                size: size * 0.46,
                color: color ?? Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
