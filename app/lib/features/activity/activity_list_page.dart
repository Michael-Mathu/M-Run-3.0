import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/data/gpx_export.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_app/data/sample_activities.dart';
import 'package:mwendo_app/widgets/app_card.dart';
import 'package:mwendo_app/widgets/route_thumbnail.dart';
import 'package:mwendo_app/widgets/skeleton.dart';
import 'package:mwendo_app/widgets/trailing_chevron.dart';

enum _Sort { date, distance, duration }

class ActivityListPage extends ConsumerStatefulWidget {
  const ActivityListPage({super.key});

  @override
  ConsumerState<ActivityListPage> createState() => _ActivityListPageState();
}

class _ActivityListPageState extends ConsumerState<ActivityListPage> {
  _Sort _sort = _Sort.date;
  String? _typeFilter;

  List<RunRecord> _apply(List<RunRecord> runs) {
    var list = runs;
    if (_typeFilter != null) {
      list = list.where((r) => r.type == _typeFilter).toList();
    }
    list = [...list];
    switch (_sort) {
      case _Sort.date:
        list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      case _Sort.distance:
        list.sort((a, b) => b.distanceM.compareTo(a.distanceM));
      case _Sort.duration:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);
    final runs = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.tr('activity', locale))),
      body: AnimatedSwitcher(
        duration: AppTheme.dMed,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: runs.when(
          loading: () => KeyedSubtree(
            key: const ValueKey('activity-loading'),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.s24),
              itemCount: 3,
              separatorBuilder: (_, index) => const SizedBox(height: AppTheme.s12),
              itemBuilder: (_, index) => const SkeletonCard(height: 88),
            ),
          ),
          error: (_, _) => KeyedSubtree(
            key: const ValueKey('activity-error'),
            child: _EmptyState(text: text, cs: cs, locale: locale),
          ),
          data: (real) {
            final items = real.isNotEmpty ? real : <RunRecord>[];
            if (items.isEmpty) {
              return KeyedSubtree(
                key: const ValueKey('activity-empty'),
                child: _EmptyState(text: text, cs: cs, locale: locale),
              );
            }
            final types = items.map((r) => r.type).toSet().toList()..sort();
            final sorted = _apply(items);
            return KeyedSubtree(
              key: const ValueKey('activity-data'),
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(activitiesProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s8, AppTheme.s16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _Chip(
                                        label: L10n.tr('all', locale),
                                        active: _typeFilter == null,
                                        onTap: () => setState(() => _typeFilter = null),
                                      ),
                                      for (final t in types)
                                        _Chip(
                                          label: t,
                                          active: _typeFilter == t,
                                          onTap: () => setState(() => _typeFilter = t),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.s8),
                          Row(
                            children: [
                              Text(L10n.tr('sort', locale),
                                  style: text.labelMedium!.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.6))),
                              const SizedBox(width: AppTheme.s8),
                              DropdownButton<_Sort>(
                                value: _sort,
                                underline: const SizedBox.shrink(),
                                items: [
                                  DropdownMenuItem(
                                      value: _Sort.date,
                                      child: Text(L10n.tr('sort_date', locale))),
                                  DropdownMenuItem(
                                      value: _Sort.distance,
                                      child: Text(L10n.tr('sort_distance', locale))),
                                  DropdownMenuItem(
                                      value: _Sort.duration,
                                      child: Text(L10n.tr('sort_duration', locale))),
                                ],
                                onChanged: (s) => setState(() => _sort = s!),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.file_download_outlined, size: 18),
                                label: Text(L10n.tr('export_json', locale)),
                                onPressed: () => _exportJson(context, ref, locale, sorted),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s8, AppTheme.s16, 120),
                      sliver: SliverList.separated(
                        separatorBuilder: (_, index) => const SizedBox(height: AppTheme.s8),
                        itemCount: sorted.length,
                        itemBuilder: (_, i) => _ActivityTile(
                          a: sorted[i].toSampleActivity(),
                          onExportGpx: () => _exportGpx(context, ref, locale, sorted[i]),
                          onTap: () => GoRouter.of(context).go('/activity/${sorted[i].id}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref, AppLocale locale,
      List<RunRecord> runs) async {
    final json = jsonFromRuns(runs);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'mwendo_activities.json'));
    await file.writeAsString(json);
    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(text: L10n.tr('exported', locale), files: [XFile(file.path)]),
      );
    }
  }

  Future<void> _exportGpx(BuildContext context, WidgetRef ref, AppLocale locale,
      RunRecord run) async {
    final gpx = gpxFromRunRecord(run);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${run.id}.gpx'));
    await file.writeAsString(gpx);
    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(text: L10n.tr('exported', locale), files: [XFile(file.path)]),
      );
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.s8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s8),
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.rFull),
          ),
          child: Text(label,
              style: text.labelLarge!.copyWith(
                  color: active ? Colors.white : Theme.of(context).colorScheme.onSurface)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TextTheme text;
  final ColorScheme cs;
  final AppLocale locale;

  const _EmptyState({required this.text, required this.cs, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_run_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: AppTheme.s16),
            Text(L10n.tr('no_runs_yet', locale), style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.s8),
            Text(L10n.tr('routes_will_show', locale), style: text.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  final SampleActivity a;
  final VoidCallback onExportGpx;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.a,
    required this.onExportGpx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.s12),
      onTap: onTap,
      useInkWell: true,
      child: Row(
        children: [
          RouteThumbnail(
            segments: a.routeSegments,
            size: 56,
            fallbackIcon:
                a.type == 'Run' ? Icons.directions_run_rounded : Icons.directions_bike_rounded,
          ),
          const SizedBox(width: AppTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDistance(a.distanceM), style: text.titleMedium),
                const SizedBox(height: AppTheme.s2),
                Text(
                  '${a.type} · ${formatDuration(a.durationMs)}',
                  style: text.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  formatDate(a.startedAt),
                  style: text.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.ios_share_rounded, size: 20, color: cs.primary),
            tooltip: L10n.tr('export_gpx', locale),
            onPressed: onExportGpx,
          ),
          const TrailingChevron(),
        ],
      ),
    );
  }
}