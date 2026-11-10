import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';
import 'package:mwendo_app/features/learn/data/legend_of_day.dart';
import 'package:mwendo_app/features/learn/data/legends.dart';
import 'package:mwendo_app/features/legends/legend_widgets.dart';
import 'package:mwendo_app/widgets/ios.dart';

/// The Legends tab: a featured "Legend of the day", a carousel of legendary
/// performances to race, and the full searchable roster.
class LegendsHomePage extends ConsumerStatefulWidget {
  const LegendsHomePage({super.key});

  @override
  ConsumerState<LegendsHomePage> createState() => _LegendsHomePageState();
}

const _kCountries = ['All', 'Kenya', 'Ethiopia', 'Uganda'];
const _kDisciplines = [
  'All',
  'Marathon',
  'Half Marathon',
  '10,000m',
  '5000m',
  '1500m',
  '800m',
  'Cross Country',
];
const _kEras = ['All', '1960s–70s', '1980s–90s', '2000s–10s', '2020s+'];

class _LegendsHomePageState extends ConsumerState<LegendsHomePage> {
  final _q = TextEditingController();
  String _query = '';
  String _country = 'All';
  String _discipline = 'All';
  String _era = 'All';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool get _searching => _query.trim().isNotEmpty;

  List<Legend> get _filtered {
    final q = _query.trim().toLowerCase();
    const en = AppLocale.english;
    return legends.where((l) {
      if (q.isNotEmpty &&
          !(l.name.toLowerCase().contains(q) ||
              lt(l.country, en).toLowerCase().contains(q) ||
              lt(l.discipline, en).toLowerCase().contains(q))) {
        return false;
      }
      if (_country != 'All' && !lt(l.country, en).startsWith(_country)) return false;
      if (_discipline != 'All' &&
          !lt(l.discipline, en).toLowerCase().contains(_discipline.toLowerCase())) {
        return false;
      }
      if (_era != 'All' && lt(l.eraLabel, en) != _era) return false;
      return true;
    }).toList();
  }

  void _pickEra(AppLocale locale) {
    Haptics.light();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(L10n.tr('era', locale)),
        actions: [
          for (final e in _kEras)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _era = e);
                Navigator.of(ctx).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(e == 'All' ? L10n.tr('all', locale) : e),
                  if (e == _era) ...[
                    const SizedBox(width: AppTheme.s8),
                    const Icon(CupertinoIcons.checkmark_alt, size: 18),
                  ],
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(L10n.tr('cancel', locale)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final appLocale = locale == AppLocale.swahili ? AppLocale.swahili : AppLocale.english;
    final featured = ref.watch(legendOfDayProvider);
    final results = _filtered;
    final cs = Theme.of(context).colorScheme;

    String countryLabel(String c) => switch (c) {
          'Kenya' => '🇰🇪 Kenya',
          'Ethiopia' => '🇪🇹 Ethiopia',
          'Uganda' => '🇺🇬 Uganda',
          _ => L10n.tr('all', locale),
        };

    return LargeTitlePage(
      title: L10n.tr('legends_title', locale),
      trailing: IosBarButton(
        icon: CupertinoIcons.line_horizontal_3_decrease,
        semanticLabel: L10n.tr('era', locale),
        highlighted: _era != 'All',
        onTap: () => _pickEra(locale),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: IosSearchField(
            controller: _q,
            placeholder: L10n.tr('search_legends', locale),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (!_searching) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s16, kIosGutter, 0),
              child: _FeaturedLegend(legend: featured, locale: appLocale),
            ),
          ),
          SliverToBoxAdapter(
            child: IosSectionHeader(
              title: L10n.tr('race_a_legend', locale),
              actionLabel: L10n.tr('see_all', locale),
              onAction: () => context.push('/beat'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 164 + 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: ghostPaces.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s12),
                itemBuilder: (_, i) => GhostRaceCard(ghost: ghostPaces[i]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: IosSectionHeader(title: L10n.tr('all_legends', locale)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
              child: IosSegmented<String>(
                value: _country,
                segments: {for (final c in _kCountries) c: countryLabel(c)},
                onChanged: (v) {
                  Haptics.selection();
                  setState(() => _country = v);
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.s12)),
          SliverToBoxAdapter(
            child: IosFilterPills(
              options: _kDisciplines,
              selected: _discipline,
              labelOf: (d) => d == 'All' ? L10n.tr('all_distances', locale) : d,
              onSelected: (v) {
                Haptics.selection();
                setState(() => _discipline = v);
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.s16)),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.s12)),
        if (results.isEmpty)
          SliverToBoxAdapter(
            child: _NoMatches(
              locale: locale,
              onSuggestion: (q) {
                _q.text = q;
                setState(() {
                  _query = q;
                  _country = 'All';
                  _discipline = 'All';
                  _era = 'All';
                });
              },
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: IosInsetGroup(
              dividerIndent: AppTheme.s16 + 46 + AppTheme.s14,
              children: [for (final l in results) LegendRow(legend: l, locale: appLocale)],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kIosGutter * 2, AppTheme.s8, kIosGutter, 0),
              child: Text(
                '${results.length} ${L10n.tr('legendary_runners', locale)}',
                style: AppTheme.bodyFont(size: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Big App Store–style feature card for the legend of the day.
class _FeaturedLegend extends StatelessWidget {
  final Legend legend;
  final AppLocale locale;
  const _FeaturedLegend({required this.legend, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l = legend;
    return Semantics(
      container: true,
      label: '${L10n.tr('legend_of_the_day', locale)}: ${l.name}',
      child: GestureDetector(
        onTap: () => context.push('/legends/${l.slug}'),
        child: Container(
          decoration: BoxDecoration(
            gradient: legendGradient(l),
            borderRadius: BorderRadius.circular(AppTheme.r24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.s20, AppTheme.s20, AppTheme.s20, AppTheme.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            L10n.tr('legend_of_the_day', locale).toUpperCase(),
                            style: AppTheme.bodyFont(
                              size: 12,
                              weight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8),
                            ).copyWith(letterSpacing: 0.6),
                          ),
                        ),
                        LegendAvatar(legend: l, size: 104, ring: true),
                      ],
                    ),
                    const SizedBox(height: AppTheme.s12),
                    Text(
                      l.name,
                      style: AppTheme.bodyFont(size: 30, weight: FontWeight.w800, color: Colors.white, height: 1.05)
                          .copyWith(letterSpacing: -0.8),
                    ),
                    const SizedBox(height: AppTheme.s6),
                    Text(
                      '${l.flag}  ${lt(l.discipline, locale)} · ${lt(l.country, locale)}',
                      style: AppTheme.bodyFont(size: 15, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: AppTheme.s8),
                    Text(
                      lt(l.tagline, locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: AppTheme.s16),
                    Wrap(
                      spacing: AppTheme.s8,
                      runSpacing: AppTheme.s8,
                      children: [
                        ArtworkButton(
                          label: L10n.tr('read_story', locale),
                          icon: CupertinoIcons.book_fill,
                          onTap: () => context.push('/legends/${l.slug}'),
                        ),
                        if (l.beatLegendId != null)
                          ArtworkButton(
                            label: L10n.tr('race', locale),
                            icon: CupertinoIcons.play_fill,
                            filled: false,
                            onTap: () => context.push('/beat/${l.beatLegendId}'),
                          ),
                      ],
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  final AppLocale locale;
  final ValueChanged<String> onSuggestion;
  const _NoMatches({required this.locale, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const popular = ['Kipchoge', 'Ethiopia', 'Kipyegon', 'Cheptegei', 'Haile'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s48, kIosGutter, 0),
      child: Column(
        children: [
          Icon(CupertinoIcons.search, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: AppTheme.s12),
          Text(
            L10n.tr('no_legends_match', locale),
            textAlign: TextAlign.center,
            style: AppTheme.bodyFont(size: 20, weight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: AppTheme.s6),
          Text(
            L10n.tr('try_search', locale),
            textAlign: TextAlign.center,
            style: AppTheme.bodyFont(size: 15, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.s20),
          Wrap(
            spacing: AppTheme.s8,
            runSpacing: AppTheme.s8,
            alignment: WrapAlignment.center,
            children: [
              for (final p in popular)
                ActionChip(
                  label: Text(p),
                  onPressed: () => onSuggestion(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
