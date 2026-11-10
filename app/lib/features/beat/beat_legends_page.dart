import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/features/beat/pre_race_sheet.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';
import 'package:mwendo_app/features/learn/data/legends.dart';
import 'package:mwendo_app/features/legends/legend_widgets.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_app/widgets/ios.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Recommends the hardest tier of [ghost] the user could realistically beat,
/// based on their personal best for that distance (or null if no PB / the
/// user could already beat the GOAT tier). PBs are in seconds.
DifficultyTier? _recommendedTierFor(GhostPace ghost, Map<String, int> pbMap) {
  final userPb = pbMap[ghost.distanceLabel];
  if (userPb == null) return null;

  for (final tier in DifficultyTier.values.reversed) {
    final scaled = (ghost.totalSeconds * tier.factor).round();
    if (userPb <= scaled) {
      return tier == DifficultyTier.goat ? null : DifficultyTier.values[tier.index + 1];
    }
  }
  return DifficultyTier.bronze;
}

/// "Beat the Legends": pick a legendary performance, pick a difficulty, see
/// the pacing, and start the race.
class BeatLegendsPage extends ConsumerStatefulWidget {
  final String? id;
  const BeatLegendsPage({super.key, this.id});

  @override
  ConsumerState<BeatLegendsPage> createState() => _BeatLegendsPageState();
}

class _BeatLegendsPageState extends ConsumerState<BeatLegendsPage> {
  late GhostPace _selected;
  DifficultyTier _tier = DifficultyTier.goat;
  String _filter = 'all'; // 'all' or distance label

  @override
  void initState() {
    super.initState();
    _selected = widget.id != null ? ghostPaceForId(widget.id!) : ghostPaces.first;
  }

  List<GhostPace> get _filteredGhosts {
    if (_filter == 'all') return ghostPaces;
    return ghostPaces.where((g) => g.distanceLabel == _filter).toList();
  }

  List<String> get _distanceLabels {
    final labels = ghostPaces.map((g) => g.distanceLabel).toSet().toList();
    labels.sort((a, b) => _distanceOrder(a).compareTo(_distanceOrder(b)));
    return labels;
  }

  int _distanceOrder(String label) {
    switch (label) {
      case '800m': return 0;
      case '1500m': return 1;
      case '5000m': return 2;
      case '10,000m': return 3;
      case '10K': return 4;
      case 'Marathon': return 5;
      default: return 99;
    }
  }

  GhostPace get _active => _selected.forTier(_tier);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);
    final activities = ref.watch(activitiesProvider);

    // User's PB (seconds) per distance.
    final pbMap = activities.maybeWhen(
      data: (list) => _computePBs(list),
      orElse: () => <String, int>{},
    );
    final recommended = _recommendedTierFor(_selected, pbMap);

    return LargeTitlePage(
      title: L10n.tr('beat_the_legends', locale),
      showBack: true,
      inTabBar: false,
      slivers: [
        // Distance filter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppTheme.s8),
            child: IosFilterPills(
              options: ['all', ..._distanceLabels],
              selected: _filter,
              labelOf: (v) => v == 'all' ? L10n.tr('all_distances', locale) : v,
              onSelected: (v) {
                Haptics.selection();
                setState(() {
                  _filter = v;
                  if (!_filteredGhosts.any((g) => g.id == _selected.id)) {
                    _selected = _filteredGhosts.first;
                  }
                });
              },
            ),
          ),
        ),

        // Legend picker
        SliverToBoxAdapter(
          child: SizedBox(
            height: 112,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s16, kIosGutter, 0),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredGhosts.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s14),
              itemBuilder: (_, i) {
                final g = _filteredGhosts[i];
                final active = g.id == _selected.id;
                return Semantics(
                  button: true,
                  selected: active,
                  label: '${g.legend.name}, ${g.distanceLabel}',
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: () {
                      Haptics.selection();
                      setState(() => _selected = g);
                    },
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: AppTheme.motion(context, AppTheme.dFast),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: active ? cs.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: LegendAvatar(legend: g.legend, size: 56),
                          ),
                          const SizedBox(height: AppTheme.s6),
                          Text(
                            g.legend.name.split(' ').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodyFont(
                              size: 12,
                              weight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? cs.onSurface : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Hero card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s16, kIosGutter, 0),
            child: _GhostHero(g: _active, locale: locale, userPb: pbMap[_selected.distanceLabel]),
          ),
        ),

        // Difficulty
        SliverToBoxAdapter(
          child: IosSectionHeader(title: L10n.tr('difficulty', locale)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
            child: IosSegmented<DifficultyTier>(
              value: _tier,
              segments: {for (final t in DifficultyTier.values) t: '${t.badge} ${t.label}'},
              onChanged: (t) {
                Haptics.selection();
                setState(() => _tier = t);
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter + AppTheme.s4, AppTheme.s8, kIosGutter, 0),
            child: Text(
              recommended != null
                  ? '${L10n.tr('tier_recommendation', locale)} ${recommended.badge} ${recommended.label} — ${L10n.tr('based_on_your_pb', locale)}'
                  : L10n.tr('tier_explainer', locale),
              style: AppTheme.bodyFont(size: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ),

        // Pace chart
        SliverToBoxAdapter(
          child: IosSectionHeader(title: L10n.tr('pace_per_segment', locale)),
        ),
        SliverToBoxAdapter(
          child: IosInsetGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.s12, AppTheme.s16, AppTheme.s16, AppTheme.s8),
                child: SizedBox(height: 160, child: _SplitsChart(g: _active)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s10, AppTheme.s16, AppTheme.s12),
                child: Text(
                  _active.description,
                  style: AppTheme.bodyFont(size: 15, height: 1.45, color: cs.onSurface),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter + AppTheme.s4, AppTheme.s6, kIosGutter, 0),
            child: Text(
              L10n.tr('seconds_per_km', locale),
              style: AppTheme.bodyFont(size: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ),

        // Start
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s28, kIosGutter, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Haptics.medium();
                  showPreRaceSheet(context, ref, _selected, _tier);
                },
                icon: const Icon(CupertinoIcons.play_fill, size: 18),
                label: Text(L10n.tr('race_this_ghost', locale)),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter * 2, AppTheme.s12, kIosGutter * 2, 0),
            child: Text(
              '${L10n.tr('during_a_run', locale)}${formatDuration(_active.totalSeconds * 1000)}.',
              style: AppTheme.bodyFont(size: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, int> _computePBs(List<RunRecord> activities) {
    final pbs = <String, int>{};
    for (final a in activities) {
      final distLabel = _distanceLabelFromKm(a.distanceM / 1000);
      final timeSec = a.durationMs ~/ 1000;
      if (!pbs.containsKey(distLabel) || timeSec < pbs[distLabel]!) {
        pbs[distLabel] = timeSec;
      }
    }
    return pbs;
  }

  String _distanceLabelFromKm(double km) {
    if (km < 1) return '800m';
    if (km < 2) return '1500m';
    if (km < 6) return '5000m';
    if (km < 15) return '10K';
    return 'Marathon';
  }
}

/// Gradient artwork card for the selected performance at the chosen tier.
class _GhostHero extends StatelessWidget {
  final GhostPace g;
  final AppLocale locale;
  final int? userPb; // seconds

  const _GhostHero({required this.g, required this.locale, required this.userPb});

  @override
  Widget build(BuildContext context) {
    final l = g.legend;
    final pbComparison = userPb != null ? ((g.totalSeconds - userPb!) / userPb! * 100).round() : null;
    final white70 = Colors.white.withValues(alpha: 0.8);

    return Container(
      decoration: BoxDecoration(
        gradient: legendGradient(l),
        borderRadius: BorderRadius.circular(AppTheme.r24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: AppTheme.s20,
            top: AppTheme.s20,
            child: LegendAvatar(legend: l, size: 84, ring: true),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.flag}  ${g.distanceLabel}'.toUpperCase(),
                  style: AppTheme.bodyFont(size: 12, weight: FontWeight.w700, color: white70)
                      .copyWith(letterSpacing: 0.6),
                ),
                const SizedBox(height: AppTheme.s4),
                Padding(
                  // Keep the title clear of the portrait in the corner.
                  padding: const EdgeInsets.only(right: 96),
                  child: Text(
                    g.name,
                    style: AppTheme.bodyFont(size: 22, weight: FontWeight.w700, color: Colors.white)
                        .copyWith(letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: AppTheme.s20),
                Text(
                  L10n.tr('target', locale),
                  style: AppTheme.bodyFont(size: 13, weight: FontWeight.w600, color: white70),
                ),
                Text(
                  formatDuration(g.totalSeconds * 1000),
                  style: AppTheme.displayFont(size: 54, weight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: AppTheme.s4),
                Text(
                  '${L10n.tr('avg', locale)} ${formatPace(g.avgPaceMinPerKm)} /km',
                  style: AppTheme.bodyFont(size: 15, weight: FontWeight.w500, color: white70),
                ),
                if (userPb != null) ...[
                  const SizedBox(height: AppTheme.s16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppTheme.r12),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.rosette, color: Colors.white, size: 18),
                        const SizedBox(width: AppTheme.s8),
                        Expanded(
                          child: Text(
                            '${L10n.tr('your_pb', locale)} ${formatDuration(userPb! * 1000)} · '
                            '${pbComparison! > 0 ? '+$pbComparison% ${L10n.tr('slower_than_ghost', locale)}' : '${pbComparison.abs()}% ${L10n.tr('faster_than_ghost', locale)}'}',
                            style: AppTheme.bodyFont(size: 14, weight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitsChart extends StatelessWidget {
  final GhostPace g;
  const _SplitsChart({required this.g});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = legendAccent(g.legend);
    final accent = dark ? Color.lerp(base, Colors.white, 0.25)! : base;
    final axisText = AppTheme.monoFont(size: 11, color: cs.onSurfaceVariant);
    final (min, max) = g.splits.fold<(double, double)>(
      (double.infinity, double.negativeInfinity),
      ((double, double) acc, double v) => (math.min(acc.$1, v), math.max(acc.$2, v)),
    );
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < g.splits.length; i++) FlSpot(i.toDouble(), g.splits[i])],
            color: accent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            isCurved: true,
            curveSmoothness: 0.3,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt() + 1}', style: axisText),
              interval: (g.splits.length / 6).ceilToDouble().clamp(1, 999),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text('${v.toInt()}s', style: axisText),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.onSurface.withValues(alpha: 0.08), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        minY: min * 0.95,
        maxY: max * 1.05,
      ),
    );
  }
}
