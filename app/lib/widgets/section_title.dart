import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';

/// Section header used across the app: a bold title in the label colour with
/// an optional "See All" in the tint colour, as in Apple Fitness and the App
/// Store. (Replaces the tracked mono-caps eyebrow, which read as decoration
/// rather than structure.)
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {this.actionLabel, this.onAction, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.s8, bottom: AppTheme.s8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTheme.bodyFont(
                        size: 22, weight: FontWeight.w700, height: 1.2, color: cs.onSurface)
                    .copyWith(letterSpacing: -0.4),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppTheme.minTap, AppTheme.minTap),
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: AppTheme.bodyFont(size: 17, color: cs.primary),
              ),
            ),
        ],
      ),
    );
  }
}
