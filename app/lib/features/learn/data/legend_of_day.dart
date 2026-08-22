import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/features/learn/data/legends.dart';

/// Deterministic "Legend of the Day" — same legend for everyone on a given day,
/// rotating through the list by day-of-year.
final legendOfDayProvider = Provider<Legend>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(start).inDays;
  return legends[dayOfYear % legends.length];
});

/// "Legend of the Week" — rotates weekly.
final legendOfWeekProvider = Provider<Legend>((ref) {
  final now = DateTime.now();
  final weekOfYear = (now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor();
  return legends[weekOfYear % legends.length];
});

class LegendOfDayCard extends ConsumerWidget {
  final bool weekly;
  const LegendOfDayCard({super.key, this.weekly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legend = weekly ? ref.watch(legendOfWeekProvider) : ref.watch(legendOfDayProvider);
    final accent = legendAccent(legend);
    final text = Theme.of(context).textTheme;
    final locale = ref.read(localeProvider);

    // A legend's accent can be a light dawn gold or a dark earth/highland.
    // Render the card at full strength (opaque, gently darkened toward the
    // bottom) and pick a foreground by the accent's luminance so dawn gold
    // gets dark ink while earth/highland get cream — both stay legible.
    final fg = accent.computeLuminance() > 0.30 ? AppTheme.onLight : Colors.white;
    final fgSoft = fg.withValues(alpha: 0.82);

    return Container(
      padding: const EdgeInsets.all(AppTheme.s20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.r24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.s10, vertical: AppTheme.s4),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.rFull),
                ),
                child: Text(weekly ? L10n.tr('legend_of_week', locale) : L10n.tr('did_you_know', locale),
                    style: text.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: fg.withValues(alpha: 0.18),
                child: Text(legend.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: AppTheme.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(legend.name,
                        style: text.titleLarge!.copyWith(color: fg)),
                    const SizedBox(height: AppTheme.s2),
                    Text(legend.flag,
                        style: text.bodySmall!.copyWith(color: fgSoft)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s12),
          Text(
            lt(legend.funFact ?? legend.tagline, locale),
            style: text.bodyMedium!.copyWith(color: fgSoft, height: 1.5),
          ),
          const SizedBox(height: AppTheme.s12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/learn/legends/${legend.slug}'),
              icon: Icon(Icons.arrow_forward_rounded, color: fg),
              label: Text(L10n.tr('read_more', locale), style: TextStyle(color: fg)),
              style: TextButton.styleFrom(foregroundColor: fg),
            ),
          ),
        ],
      ),
    );
  }
}