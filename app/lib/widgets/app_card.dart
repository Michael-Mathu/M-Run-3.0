import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Canonical card component used across the app.
/// Replaces 15+ ad-hoc Container/Material card patterns.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  final bool useInkWell;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.s16),
    this.margin = EdgeInsets.zero,
    this.shadows = AppTheme.elevation1,
    this.color,
    this.borderRadius,
    this.border,
    this.onTap,
    this.useInkWell = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = color ?? cs.surface;
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.r16);

    final decoratedChild = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: radius,
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );

    if (onTap == null) return decoratedChild;

    // Same press feedback everywhere (dim + slight shrink), whether or not
    // the caller asked for the old ink well.
    return Pressable(onTap: onTap, child: decoratedChild);
  }
}

/// Gradient variant of AppCard for tiered/brand cards.
class AppGradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const AppGradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.padding = const EdgeInsets.all(AppTheme.s16),
    this.margin = EdgeInsets.zero,
    this.borderRadius,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.r16);

    final decoratedChild = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap == null) return decoratedChild;

    return Pressable(onTap: onTap, child: decoratedChild);
  }
}

/// Pre-defined gradient card for challenge/achievement tiers.
class TierCard extends StatelessWidget {
  final Widget child;
  final Color tierColor;
  final bool isCompleted;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const TierCard({
    super.key,
    required this.child,
    required this.tierColor,
    this.isCompleted = false,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progressColor = isCompleted ? context.tokens.flagGreen : tierColor;

    // Flat card; the tier shows as a quiet tint, completion as a crisp
    // coloured edge (the old glowing shadow competed with the content).
    return AppCard(
      color: Color.alphaBlend(tierColor.withValues(alpha: 0.07), cs.surface),
      padding: padding ?? const EdgeInsets.all(AppTheme.s16),
      border: isCompleted ? Border.all(color: progressColor, width: 1.5) : null,
      onTap: onTap,
      child: child,
    );
  }
}