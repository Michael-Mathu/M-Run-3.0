import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/features/tracking/tracking_controller.dart';

class RecoveryCard extends ConsumerWidget {
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const RecoveryCard({
    super.key,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(trackingModelProvider);
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);

    return Container(
      margin: const EdgeInsets.all(AppTheme.s16),
      padding: const EdgeInsets.all(AppTheme.s20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.r24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restore, color: Colors.orange),
              ),
              const SizedBox(width: AppTheme.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.tr('run_recovered', locale),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      L10n.tr('run_recovered_body', locale),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                label: L10n.tr('distance', locale),
                value: '${(m.distanceM / 1000).toStringAsFixed(2)} km',
              ),
              _Stat(
                label: L10n.tr('time', locale),
                value: formatDuration(m.elapsedMs),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(L10n.tr('discard_run_title', locale)),
                        content: Text(L10n.tr('discard_run_body', locale)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(L10n.tr('cancel', locale)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.sos),
                            child: Text(L10n.tr('discard', locale)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      onDiscard();
                    }
                  },
                  child: Text(L10n.tr('discard', locale)),
                ),
              ),
              const SizedBox(width: AppTheme.s12),
              Expanded(
                child: FilledButton(
                  onPressed: onResume,
                  child: Text(L10n.tr('resume_run', locale)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}
