import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/widgets/pressable.dart';
import 'package:mwendo_app/widgets/trailing_chevron.dart';

/// Apple "inset grouped" list section: a rounded white (or dark grey) block on
/// the grouped background, rows separated by hairlines inset past the icon,
/// an optional small header above and footer below.
class GroupedSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: AppTheme.s24),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Divider(height: 0.5, thickness: 0.5, color: cs.outlineVariant),
        ));
      }
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.s16, 0, AppTheme.s16, AppTheme.s8),
              child: Text(
                header!.toUpperCase(),
                style: text.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.r12),
            child: ColoredBox(
              color: cs.surface,
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s8, AppTheme.s16, 0),
              child: Text(
                footer!,
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row in a [GroupedSection]: coloured rounded-square icon, title,
/// optional subtitle, optional right-aligned value, chevron when tappable.
class GroupedRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  /// Defaults to true when the row is tappable and has no [trailing].
  final bool? showChevron;
  final bool destructive;

  const GroupedRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tint = iconColor ?? cs.primary;
    final chevron = showChevron ?? (onTap != null && trailing == null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTheme.minTap + 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s10),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppTheme.s14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge?.copyWith(
                      color: destructive ? cs.error : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.s8),
                child: Text(
                  value!,
                  style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.s8),
                child: trailing!,
              ),
            if (chevron)
              const Padding(
                padding: EdgeInsets.only(left: AppTheme.s4),
                child: TrailingChevron(size: 18),
              ),
          ],
        ),
      ),
    );
    final semantic = Semantics(
      button: onTap != null,
      label: [title, subtitle, value].whereType<String>().join(', '),
      excludeSemantics: trailing == null,
      child: row,
    );
    if (onTap == null) return semantic;
    return Pressable(onTap: onTap, pressedScale: 1, pressedOpacity: 0.55, child: semantic);
  }
}
