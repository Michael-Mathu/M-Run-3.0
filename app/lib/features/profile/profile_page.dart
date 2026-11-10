import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mwendo_app/core/gamification/gamification_provider.dart';
import 'package:mwendo_app/core/gamification/leaderboard_data.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/network/leaderboard_provider.dart';
import 'package:mwendo_app/core/network/session_provider.dart';
import 'package:mwendo_app/core/profile/profile_provider.dart';
import 'package:mwendo_app/core/safety/safety_provider.dart';
import 'package:mwendo_app/data/gpx_export.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';
import 'package:mwendo_app/features/safety/safety_service.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/widgets/celebration_overlay.dart';
import 'package:mwendo_app/widgets/grouped_section.dart';
import 'package:mwendo_app/widgets/section_title.dart';
import 'package:mwendo_app/core/theme/theme_mode_provider.dart';
import 'package:mwendo_app/core/theme/palette_provider.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/widgets/level_ring.dart';
import 'package:mwendo_app/widgets/ios.dart';
import 'package:mwendo_app/core/perf/glass_quality.dart';
import 'package:mwendo_app/features/legends/photo_credits_page.dart';
import 'package:mwendo_app/features/legends/legend_widgets.dart';


class YouPage extends ConsumerStatefulWidget {
  const YouPage({super.key});

  @override
  ConsumerState<YouPage> createState() => _YouPageState();
}

class _YouPageState extends ConsumerState<YouPage> {
  int _prevLevel = 0;
  bool _showLevelUp = false;
  String _levelUpTitle = '';
  _StatRange _range = _StatRange.all;

  void _setRange(_StatRange r) {
    if (r == _range) return;
    Haptics.selection();
    setState(() => _range = r);
  }

  @override
  void initState() {
    super.initState();
    _prevLevel = ref.read(gamificationProvider).level;
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gamificationProvider);
    final locale = ref.watch(localeProvider);
    if (g.level > _prevLevel && _prevLevel > 0) {
      _prevLevel = g.level;
      Haptics.celebrate();
      _levelUpTitle = '${L10n.tr('level', locale)} ${g.level}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showLevelUp = true);
      });
    } else {
      _prevLevel = g.level;
    }
    final profile = ref.watch(userProfileProvider);
    final units = ref.watch(unitsProvider);
    final contacts = ref.watch(safetyContactsProvider);
    final session = ref.watch(sessionProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final runs = ref.watch(activitiesProvider).value ?? const <RunRecord>[];
    final rank = _rankFor(ref, g.xp);

    void open(Widget page) {
      Haptics.selection();
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        LargeTitlePage(
              title: L10n.tr('you', locale),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s8, AppTheme.s16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ---- Profile header -----------------------------------
                      Row(
                        children: [
                          Semantics(
                            label: L10n.tr('edit', locale),
                            button: true,
                            child: GestureDetector(
                              onTap: () => _EditPhotoSheet.show(context, ref),
                              child: LevelAvatar(
                                level: g.level,
                                progress: g.levelProgress,
                                avatar: profile.photoPath != null
                                    ? CircleAvatar(
                                        radius: 34,
                                        backgroundImage: FileImage(File(profile.photoPath!)),
                                      )
                                    : CircleAvatar(
                                        radius: 34,
                                        backgroundColor: cs.primary.withValues(alpha: 0.15),
                                        child: Icon(CupertinoIcons.person_fill,
                                            color: cs.primary, size: 34),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.s16),
                          Expanded(
                            child: Semantics(
                              label: L10n.tr('edit', locale),
                              button: true,
                              child: GestureDetector(
                                onTap: () => _EditNameSheet.show(context, ref, profile.username),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(profile.username,
                                        style: text.headlineMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('${L10n.tr('level', locale)} ${g.level} · ${g.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.s16),
                      XpBar(
                        xpIntoLevel: g.xpIntoLevel,
                        xpForNextLevel: g.xpForNextLevel,
                        progress: g.levelProgress,
                      ),
                      const SizedBox(height: AppTheme.s20),
                      // ---- Stats --------------------------------------------
                      IosSegmented<_StatRange>(
                        value: _range,
                        segments: {
                          _StatRange.week: L10n.tr('stats_week', locale),
                          _StatRange.month: L10n.tr('stats_month', locale),
                          _StatRange.all: L10n.tr('all', locale),
                        },
                        onChanged: _setRange,
                      ),
                      const SizedBox(height: AppTheme.s12),
                      _StatRow(g: g, range: _range, runs: runs, units: units, locale: locale),
                      const SizedBox(height: AppTheme.s28),
                      // ---- Navigation rows (each opens its own page) --------
                      GroupedSection(
                        children: [
                          GroupedRow(
                            icon: CupertinoIcons.star_fill,
                            iconColor: AppTheme.tierGold,
                            title: L10n.tr('achievements', locale),
                            value: '${g.racedLegends.length + g.titles.length}',
                            onTap: () => open(const _AchievementsPage()),
                          ),
                          GroupedRow(
                            icon: CupertinoIcons.chart_bar_fill,
                            iconColor: const Color(0xFF5856D6),
                            title: L10n.tr('leaderboard', locale),
                            value: rank > 0 ? '#$rank' : null,
                            onTap: () => open(const _LeaderboardPage()),
                          ),
                        ],
                      ),
                      GroupedSection(
                        header: L10n.tr('safety', locale),
                        children: [
                          GroupedRow(
                            icon: Icons.sos_rounded,
                            iconColor: context.tokens.sos,
                            title: L10n.tr('emergency_contacts', locale),
                            value: contacts.isEmpty
                                ? L10n.tr('not_set', locale)
                                : '${contacts.length}',
                            onTap: () => _EmergencyContactsSheet.show(context, ref),
                          ),
                        ],
                      ),
                      GroupedSection(
                        children: [
                          GroupedRow(
                            icon: CupertinoIcons.gear_alt_fill,
                            iconColor: AppTheme.idle,
                            title: L10n.tr('settings', locale),
                            onTap: () => open(const _SettingsPage()),
                          ),
                        ],
                      ),
                      GroupedSection(
                        header: L10n.tr('account', locale),
                        children: [
                          GroupedRow(
                            icon: CupertinoIcons.person_crop_circle_fill,
                            iconColor: const Color(0xFF007AFF),
                            title: session.isAnonymous
                                ? L10n.tr('continue_anonymous', locale)
                                : (session.email ?? L10n.tr('account', locale)),
                          ),
                          GroupedRow(
                            title: session.isAnonymous
                                ? L10n.tr('sign_in', locale)
                                : L10n.tr('sign_out', locale),
                            destructive: !session.isAnonymous,
                            showChevron: session.isAnonymous,
                            onTap: () {
                              if (session.isAnonymous) {
                                context.push('/auth');
                              } else {
                                ref.read(sessionProvider.notifier).logout();
                              }
                            },
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
        ),
        if (_showLevelUp)
          CelebrationOverlay(
            title: _levelUpTitle,
            subtitle: L10n.tr('level_up_subtitle', locale),
            onDone: () => setState(() => _showLevelUp = false),
          ),
      ],
    );
  }
}

int _rankFor(WidgetRef ref, int xp) {
  final board = _boardFor(ref, xp);
  return board.indexWhere((e) => e.you) + 1;
}

List<LeaderboardEntry> _boardFor(WidgetRef ref, int xp) =>
    ref.watch(remoteLeaderboardProvider(xp)).when(
          data: (b) => b,
          loading: () => leaderboardWithUser(xp),
          error: (_, _) => leaderboardWithUser(xp),
        );

/// Shared scaffold for the You sub-pages: native nav bar with back chevron.
class _SubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SubPage({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => LargeTitlePage(
        title: title,
        showBack: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s8, AppTheme.s16, 0),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      );
}

class _AchievementsPage extends ConsumerWidget {
  const _AchievementsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gamificationProvider);
    final locale = ref.watch(localeProvider);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _SubPage(
      title: L10n.tr('achievements', locale),
      children: [
        SectionTitle(L10n.tr('your_legends', locale)),
        if (g.racedLegends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.s24),
            child: Text(L10n.tr('legend_raced', locale),
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          )
        else ...[
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: g.racedLegends.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s12),
              itemBuilder: (_, i) {
                final ghost = ghostPaceForId(g.racedLegends.elementAt(i));
                final beaten = g.beatenLegends.contains(ghost.id);
                return _LegendMiniCard(ghost: ghost, beaten: beaten);
              },
            ),
          ),
          const SizedBox(height: AppTheme.s24),
        ],
        if (g.titles.isNotEmpty) ...[
          SectionTitle(L10n.tr('titles', locale)),
          Wrap(
            spacing: AppTheme.s8,
            runSpacing: AppTheme.s8,
            children: g.titles
                .map((t) => Chip(
                      label: Text(t, style: text.labelLarge!.copyWith(color: cs.primary)),
                      backgroundColor: cs.primaryContainer,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _LeaderboardPage extends ConsumerWidget {
  const _LeaderboardPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gamificationProvider);
    final locale = ref.watch(localeProvider);
    final board = _boardFor(ref, g.xp).take(10).toList();
    final rank = board.indexWhere((e) => e.you) + 1;
    return _SubPage(
      title: L10n.tr('leaderboard', locale),
      children: [
        GroupedSection(
          header: rank > 0 ? '${L10n.tr('rank', locale)} #$rank' : null,
          children: [
            for (final (i, e) in board.indexed) _LeaderRow(e: e, position: i + 1, locale: locale),
          ],
        ),
      ],
    );
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);
    final units = ref.watch(unitsProvider);
    return _SubPage(
      title: L10n.tr('settings', locale),
      children: [
        GroupedSection(
          children: [
            GroupedRow(
              icon: Icons.translate_rounded,
              iconColor: const Color(0xFF007AFF),
              title: L10n.tr('language', locale),
              trailing: SegmentedButton<AppLocale>(
                selected: {locale},
                showSelectedIcon: false,
                onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
                segments: const [
                  ButtonSegment(value: AppLocale.english, label: Text('EN')),
                  ButtonSegment(value: AppLocale.swahili, label: Text('SW')),
                ],
              ),
            ),
            GroupedRow(
              icon: Icons.straighten_rounded,
              iconColor: const Color(0xFF34C759),
              title: L10n.tr('units', locale),
              value: units == Units.metric
                  ? L10n.tr('metric', locale)
                  : L10n.tr('imperial', locale),
              onTap: () => ref.read(unitsProvider.notifier).toggle(),
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedRow(
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF5856D6),
              title: L10n.tr('appearance', locale),
              value: mode == ThemeMode.dark
                  ? L10n.tr('dark', locale)
                  : (mode == ThemeMode.light
                      ? L10n.tr('light', locale)
                      : L10n.tr('system', locale)),
              onTap: () => ref.read(themeModeProvider.notifier).cycle(),
            ),
            _ThemePickerTile(locale: locale),
            if (GlassQuality.instance != null)
              ListenableBuilder(
                listenable: GlassQuality.instance!,
                builder: (context, _) {
                  final glass = GlassQuality.instance!;
                  final mode = glass.mode;
                  return GroupedRow(
                    icon: CupertinoIcons.circle_lefthalf_fill,
                    iconColor: const Color(0xFF32ADE6),
                    title: L10n.tr('transparency_effects', locale),
                    value: switch (mode) {
                      GlassMode.auto => glass.blurEnabled
                          ? L10n.tr('auto_label', locale)
                          : L10n.tr('auto_reduced', locale),
                      GlassMode.on => L10n.tr('on_label', locale),
                      GlassMode.off => L10n.tr('off_label', locale),
                    },
                    onTap: glass.cycle,
                  );
                },
              ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedRow(
              icon: Icons.ios_share_rounded,
              iconColor: const Color(0xFFFF9500),
              title: L10n.tr('export_data', locale),
              onTap: () => _exportData(context, ref, locale),
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedRow(
              icon: CupertinoIcons.photo_fill,
              iconColor: const Color(0xFF8E8E93),
              title: L10n.tr('photo_credits', locale),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => const PhotoCreditsPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final GamificationState g;
  final _StatRange range;
  final List<RunRecord> runs;
  final Units units;
  final AppLocale locale;
  const _StatRow({required this.g, required this.range, required this.runs, required this.units, required this.locale});

  @override
  Widget build(BuildContext context) {
    late final List<({String label, String value})> tiles;
    if (range == _StatRange.all) {
      tiles = [
        (label: L10n.tr('distance', locale), value: formatDistanceUnits(g.totalDistanceM, units)),
        (label: L10n.tr('runs', locale), value: g.totalRuns.toString()),
        (label: L10n.tr('time', locale), value: formatDuration(g.totalTimeMs)),
        (label: L10n.tr('streak', locale), value: '${g.streakDays}d'),
      ];
    } else {
      final cutoff = DateTime.now().subtract(Duration(days: range == _StatRange.week ? 7 : 30));
      final filtered = runs.where((r) => r.startedAt.isAfter(cutoff)).toList();
      final dist = filtered.fold(0.0, (s, r) => s + r.distanceM);
      final dur = filtered.fold(0, (s, r) => s + r.durationMs);
      final avgPace = dist > 0 ? (dur / 60000) / (dist / 1000) : 0.0;
      tiles = [
        (label: L10n.tr('distance', locale), value: formatDistanceUnits(dist, units)),
        (label: L10n.tr('runs', locale), value: filtered.length.toString()),
        (label: L10n.tr('time', locale), value: formatDuration(dur)),
        (label: L10n.tr('avg_pace', locale), value: avgPace > 0 ? formatPace(avgPace) : '--'),
      ];
    }
    // 2 × 2 grid of Fitness-style stat cells (four in one row overflowed:
    // "0.00 km" ran into the runs count).
    final cs = Theme.of(context).colorScheme;
    Widget cell(({String label, String value}) t) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.s14, vertical: AppTheme.s12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.r12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, style: AppTheme.bodyFont(size: 15, weight: FontWeight.w500, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(t.value,
                      style: AppTheme.displayFont(size: 30, weight: FontWeight.w700, color: cs.onSurface)),
                ),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(children: [cell(tiles[0]), const SizedBox(width: AppTheme.s10), cell(tiles[1])]),
        const SizedBox(height: AppTheme.s10),
        Row(children: [cell(tiles[2]), const SizedBox(width: AppTheme.s10), cell(tiles[3])]),
      ],
    );
  }
}

class _LegendMiniCard extends ConsumerWidget {
  final GhostPace ghost;
  final bool beaten;
  const _LegendMiniCard({required this.ghost, required this.beaten});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l = ghost.legend;
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final status = beaten ? tokens.flagGreen : tokens.idle;
    return Container(
      width: 130,
      padding: const EdgeInsets.all(AppTheme.s12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.r16),
      ),
      child: Column(
        children: [
          LegendAvatar(legend: l, size: 44),
          const SizedBox(height: AppTheme.s8),
          Text(l.name, style: Theme.of(context).textTheme.labelMedium, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppTheme.s4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: AppTheme.s2),
            decoration: BoxDecoration(
              color: status.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.rFull),
            ),
            child: Text(beaten ? L10n.tr('legend_beaten', locale) : L10n.tr('legend_raced', locale),
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: status)),
          ),
        ],
      ),
    );
  }
}

/// One leaderboard row inside a [GroupedSection]; "you" is highlighted with
/// the tint colour.
class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry e;
  final int position;
  final AppLocale locale;
  const _LeaderRow({required this.e, required this.position, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$position, ${e.you ? L10n.tr('you', locale) : e.name}, ${e.xp} XP',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('$position',
                  style: text.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            Text(e.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppTheme.s12),
            Expanded(
              child: Text(e.you ? L10n.tr('you', locale) : e.name,
                  style: text.bodyLarge!.copyWith(
                      color: e.you ? cs.primary : cs.onSurface,
                      fontWeight: e.you ? FontWeight.w700 : FontWeight.w400)),
            ),
            Text('${e.xp} XP',
                style: text.bodyMedium!.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

class _ThemePickerTile extends ConsumerWidget {
  final AppLocale locale;
  const _ThemePickerTile({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);

    return GroupedRow(
      icon: Icons.palette_rounded,
      iconColor: palette.primary,
      title: L10n.tr('color_theme', locale),
      value: _themeName(palette, locale),
      onTap: () => _showThemePicker(context, ref, locale),
    );
  }

  String _themeName(ColorPalette p, AppLocale locale) {
    final key = ColorPalette.presetsByName.entries.firstWhere((e) => e.value == p).key;
    if (key == 'redEarth') return L10n.tr('theme_red_earth', locale);
    if (key == 'orange') return L10n.tr('theme_kinetic_orange', locale);
    if (key == 'forest') return L10n.tr('theme_kenyan_green', locale);
    if (key == 'ocean') return L10n.tr('theme_midnight_blue', locale);
    if (key == 'berry') return L10n.tr('theme_berry', locale);
    return '';
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, AppLocale locale) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
      ),
      builder: (ctx) => _ThemePickerSheet(locale: locale, currentPalette: ref.read(paletteProvider)),
    );
  }
}

class _ThemePickerSheet extends ConsumerWidget {
  final AppLocale locale;
  final ColorPalette currentPalette;
  const _ThemePickerSheet({required this.locale, required this.currentPalette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palettes = ColorPalette.presets;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.s24,
        left: AppTheme.s24,
        right: AppTheme.s24,
        top: AppTheme.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.tr('choose_color_theme', locale), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.s8),
          Text(L10n.tr('color_theme_description', locale), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppTheme.s20),
          Wrap(
            spacing: AppTheme.s12,
            runSpacing: AppTheme.s12,
            children: palettes.map((p) {
              final isSelected = p == currentPalette;
              return _ThemeSwatch(
                palette: p,
                selected: isSelected,
                onTap: () {
                  Haptics.selection();
                  ref.read(paletteProvider.notifier).set(p);
                  Navigator.pop(context);
                },
                locale: locale,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final ColorPalette palette;
  final bool selected;
  final VoidCallback onTap;
  final AppLocale locale;
  const _ThemeSwatch({required this.palette, required this.selected, required this.onTap, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _themeName(palette, locale);

    return Semantics(
      label: name,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
        duration: AppTheme.dFast,
        curve: AppTheme.curveSnappy,
        width: 130,
        padding: const EdgeInsets.all(AppTheme.s16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.r16),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: palette.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [palette.primary, palette.gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(AppTheme.r12),
              ),
            ),
            const SizedBox(height: AppTheme.s12),
            Text(name, style: Theme.of(context).textTheme.titleSmall, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      ),
    );
  }

  String _themeName(ColorPalette p, AppLocale locale) {
    final key = ColorPalette.presetsByName.entries.firstWhere((e) => e.value == p).key;
    if (key == 'redEarth') return L10n.tr('theme_red_earth', locale);
    if (key == 'orange') return L10n.tr('theme_kinetic_orange', locale);
    if (key == 'forest') return L10n.tr('theme_kenyan_green', locale);
    if (key == 'ocean') return L10n.tr('theme_midnight_blue', locale);
    if (key == 'berry') return L10n.tr('theme_berry', locale);
    return '';
  }
}

Future<void> _exportData(
    BuildContext context, WidgetRef ref, AppLocale locale) async {
  final repo = ref.read(activityRepositoryProvider);
  final runs = await repo.list();
  if (runs.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.tr('nothing_recorded', locale))),
      );
    }
    return;
  }
  final json = jsonFromRuns(runs);
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'mwendo_activities.json'));
  await file.writeAsString(json);
  if (context.mounted) {
    await SharePlus.instance.share(
      ShareParams(
        text: L10n.tr('exported', locale),
        files: [XFile(file.path)],
      ),
    );
  }
}

class _EditNameSheet {
  static void show(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(L10n.tr('name', ref.read(localeProvider))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: L10n.tr('name', ref.read(localeProvider))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlg).pop(),
            child: Text(L10n.tr('cancel', ref.read(localeProvider))),
          ),
          TextButton(
            onPressed: () {
              ref.read(userProfileProvider.notifier).setUsername(ctrl.text);
              Navigator.of(dlg).pop();
            },
            child: Text(L10n.tr('save', ref.read(localeProvider))),
          ),
        ],
      ),
    );
  }
}

class _EditPhotoSheet {
  static void show(BuildContext context, WidgetRef ref) {
    final picker = ImagePicker();
    final locale = ref.read(localeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(L10n.tr('camera', locale)),
              onTap: () async {
                final img = await picker.pickImage(source: ImageSource.camera);
                if (img != null) {
                  await ref.read(userProfileProvider.notifier).setPhoto(img.path);
                }
                if (context.mounted) Navigator.of(sheet).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(L10n.tr('gallery', locale)),
              onTap: () async {
                final img = await picker.pickImage(source: ImageSource.gallery);
                if (img != null) {
                  await ref.read(userProfileProvider.notifier).setPhoto(img.path);
                }
                if (context.mounted) Navigator.of(sheet).pop();
              },
            ),
            if (ref.read(userProfileProvider).photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(L10n.tr('remove_photo', locale)),
                onTap: () async {
                  await ref.read(userProfileProvider.notifier).setPhoto(null);
                  if (context.mounted) Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContactsSheet {
  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          left: AppTheme.s24,
          right: AppTheme.s24,
          top: AppTheme.s24,
          bottom: AppTheme.s24 + MediaQuery.of(sheet).viewInsets.bottom,
        ),
        child: const _EmergencyContactsBody(),
      ),
    );
  }
}

class _EmergencyContactsBody extends ConsumerWidget {
  const _EmergencyContactsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(safetyContactsProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(L10n.tr('emergency_contacts', locale), style: text.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _editContact(context, ref, null, locale),
              icon: const Icon(Icons.add_rounded),
              label: Text(L10n.tr('add_contact', locale)),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s12),
        if (contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.s16),
            child: Text(L10n.tr('no_contacts_yet', locale),
                style: text.bodyMedium!.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.s8),
            itemBuilder: (_, i) {
              final c = contacts[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_rounded, color: AppTheme.brand),
                title: Text(c.name),
                subtitle: Text('${c.relationship} · ${c.phone}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: L10n.tr('edit', locale),
                      onPressed: () => _editContact(context, ref, i, locale),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: L10n.tr('delete', locale),
                      onPressed: () =>
                          ref.read(safetyContactsProvider.notifier).removeAt(i),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _editContact(BuildContext context, WidgetRef ref, int? index, AppLocale locale) {
    final editing = index == null ? null : ref.read(safetyContactsProvider)[index];
    final nameCtrl = TextEditingController(text: editing?.name);
    final phoneCtrl = TextEditingController(text: editing?.phone);
    final relCtrl = TextEditingController(text: editing?.relationship);

    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(index == null ? L10n.tr('add_contact', locale) : L10n.tr('edit_contact', locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: L10n.tr('name', locale)),
            ),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: L10n.tr('phone', locale)),
            ),
            TextField(
              controller: relCtrl,
              decoration: InputDecoration(labelText: L10n.tr('relationship', locale)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlg).pop(),
            child: Text(L10n.tr('cancel', locale)),
          ),
          TextButton(
            onPressed: () {
              final contact = EmergencyContact(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                relationship: relCtrl.text.trim(),
              );
              final notifier = ref.read(safetyContactsProvider.notifier);
              if (index == null) {
                notifier.add(contact);
              } else {
                notifier.update(index, contact);
              }
              Navigator.of(dlg).pop();
            },
            child: Text(L10n.tr('save', locale)),
          ),
        ],
      ),
    );
  }
}

enum _StatRange { week, month, all }