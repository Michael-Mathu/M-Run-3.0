import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';

/// Section header used across the app for visual consistency. Red Earth:
/// a tracked mono-caps "eyebrow" label (matching the redesign's scoreboard
/// idiom -- "CONTINUE LEARNING", "TODAY", "SETTINGS") instead of a full
/// Big-Shoulders titleLarge heading, so section labels read as structure,
/// not as competing headlines.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {this.actionLabel, this.onAction, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.s8, bottom: AppTheme.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTheme.monoFont(size: 12, weight: FontWeight.w600, spacing: 1.1, color: cs.primary),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: AppTheme.monoFont(
                    size: 11, weight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
}
}
