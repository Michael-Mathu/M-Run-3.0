import 'package:flutter/material.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';

class AppEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const AppEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.route_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: AppTheme.s16),
            Text(message, style: text.titleMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.s12),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
