import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Canonical button. Capsule-shaped, theme-tinted (follows the chosen
/// palette), with iOS-style press feedback. Styles map to Apple's button
/// roles: primary = filled, secondary = tinted, ghost = plain.
class AppButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.icon,
  });

  factory AppButton.primary({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    IconData? icon,
  }) =>
      AppButton(
        key: key,
        onPressed: onPressed,
        style: AppButtonStyle.primary,
        padding: padding,
        width: width,
        height: height,
        icon: icon,
        child: child,
      );

  factory AppButton.secondary({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    IconData? icon,
  }) =>
      AppButton(
        key: key,
        onPressed: onPressed,
        style: AppButtonStyle.secondary,
        padding: padding,
        width: width,
        height: height,
        icon: icon,
        child: child,
      );

  factory AppButton.ghost({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    IconData? icon,
  }) =>
      AppButton(
        key: key,
        onPressed: onPressed,
        style: AppButtonStyle.ghost,
        padding: padding,
        width: width,
        height: height,
        icon: icon,
        child: child,
      );

  factory AppButton.destructive({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    IconData? icon,
  }) =>
      AppButton(
        key: key,
        onPressed: onPressed,
        style: AppButtonStyle.destructive,
        padding: padding,
        width: width,
        height: height,
        icon: icon,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.rFull);

    final (Color background, Color foreground) = switch (style) {
      AppButtonStyle.primary => (cs.primary, cs.onPrimary),
      AppButtonStyle.secondary => (cs.primary.withValues(alpha: dark ? 0.22 : 0.12), cs.primary),
      AppButtonStyle.ghost => (Colors.transparent, cs.primary),
      AppButtonStyle.destructive => (context.tokens.danger, Colors.white),
    };
    final enabled = onPressed != null;

    Widget label = DefaultTextStyle.merge(
      style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: foreground),
      textAlign: TextAlign.center,
      child: child,
    );
    if (icon != null) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppTheme.s8),
          Flexible(child: label),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      child: Pressable(
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.4,
          duration: AppTheme.dFast,
          child: Container(
            width: width,
            height: height,
            constraints: const BoxConstraints(minHeight: 50, minWidth: AppTheme.minTap),
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: AppTheme.s24, vertical: AppTheme.s14),
            decoration: BoxDecoration(color: background, borderRadius: radius),
            alignment: Alignment.center,
            child: label,
          ),
        ),
      ),
    );
  }
}

enum AppButtonStyle { primary, secondary, ghost, destructive }
