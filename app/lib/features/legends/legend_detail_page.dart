import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/navigation/navigation.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_app/features/learn/data/courses.dart';
import 'package:mwendo_app/features/learn/data/legends.dart';
import 'package:mwendo_app/features/legends/legend_photos.dart';
import 'package:mwendo_app/features/legends/legend_widgets.dart';
import 'package:mwendo_app/features/legends/photo_credits_page.dart';
import 'package:mwendo_app/widgets/ios.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Parse a time string ("2:01:09", "12:37.35", "1:40.91") into seconds.
double _parseTimeToSeconds(String t) {
  final parts = t.split(':').map((p) => double.tryParse(p) ?? 0).toList();
  if (parts.isEmpty) return 0;
  if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length == 2) return parts[0] * 60 + parts[1];
  return parts[0];
}

/// Distance buckets a user run can match against a legend's personal best.
const Map<String, ({double meters, List<String> legendKeys})> _compareBuckets = {
  '5K': (meters: 5000, legendKeys: ['5000m', '5K']),
  '10K': (meters: 10000, legendKeys: ['10,000m', '10K (road)', '10K']),
  'Half Marathon': (meters: 21097.5, legendKeys: ['Half Marathon', 'Half']),
  'Marathon': (meters: 42195, legendKeys: ['Marathon']),
};

const double _kHeaderHeight = 360;

/// A legend's profile, laid out like an Apple Music artist page: full-bleed
/// artwork header that collapses into the navigation bar, then grouped
/// sections (bests, story, comparison, career, words, related legends).
class LegendDetailPage extends ConsumerStatefulWidget {
  final String slug;
  const LegendDetailPage({super.key, required this.slug});

  @override
  ConsumerState<LegendDetailPage> createState() => _LegendDetailPageState();
}

class _LegendDetailPageState extends ConsumerState<LegendDetailPage> {
  final _scroll = ScrollController();
  bool _collapsed = false;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final top = MediaQuery.paddingOf(context).top;
      final c = _scroll.offset > _kHeaderHeight - kToolbarHeight - top - 8;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = legendForSlug(widget.slug);
    final locale = ref.watch(localeProvider);
    final appLocale = locale == AppLocale.swahili ? AppLocale.swahili : AppLocale.english;
    final runsAsync = ref.watch(activitiesProvider);
    final cs = Theme.of(context).colorScheme;
    final accent = legendAccent(l);
    final deep = Color.lerp(accent, Colors.black, 0.55)!;
    final topInset = MediaQuery.paddingOf(context).top;

    final quotes = <({String text, String? label})>[
      for (final q in l.quotes) (text: lt(q, appLocale), label: null),
      for (final q in l.quotesExtra ?? const <LegendQuote>[])
        (
          text: lt(q.text, appLocale),
          label: LegendQuote.categoryMeta[q.category] == null
              ? null
              : lt(LegendQuote.categoryMeta[q.category]!.$2, appLocale),
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _collapsed && Theme.of(context).brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: _kHeaderHeight,
              backgroundColor: _collapsed ? Theme.of(context).scaffoldBackgroundColor : deep,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.only(left: AppTheme.s8),
                child: _collapsed
                    ? const IosBackButton()
                    : const _GlassCircleBack(),
              ),
              centerTitle: true,
              title: AnimatedOpacity(
                opacity: _collapsed ? 1 : 0,
                duration: AppTheme.motion(context, AppTheme.dFast),
                child: Text(
                  l.name,
                  style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: cs.onSurface),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                collapseMode: CollapseMode.parallax,
                background: _Header(legend: l, locale: appLocale, topInset: topInset),
              ),
            ),

            // ---- Primary actions ----
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s16, kIosGutter, 0),
                child: Row(
                  children: [
                    if (l.beatLegendId != null)
                      Expanded(
                        child: _ActionButton(
                          icon: CupertinoIcons.play_fill,
                          label: L10n.trParams('race_name', locale, {'name': l.name.split(' ').first}),
                          filled: true,
                          color: accent,
                          onTap: () => context.push('/beat/${l.beatLegendId}'),
                        ),
                      ),
                    if (l.beatLegendId != null && l.relatedCourseSlug != null)
                      const SizedBox(width: AppTheme.s12),
                    if (l.relatedCourseSlug != null)
                      Expanded(
                        child: _ActionButton(
                          icon: CupertinoIcons.book_fill,
                          label: L10n.tr('learn', locale),
                          filled: false,
                          color: accent,
                          onTap: () => context.push('/learn/course/${l.relatedCourseSlug}'),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ---- Personal bests ----
            if (l.personalBests != null && l.personalBests!.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('personal_bests', locale))),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 84,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: l.personalBests!.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s10),
                    itemBuilder: (_, i) {
                      final e = l.personalBests!.entries.elementAt(i);
                      return _BestTile(distance: distanceLabel(e.key, appLocale), time: e.value);
                    },
                  ),
                ),
              ),
            ],

            // ---- About ----
            SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('about', locale))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
                child: GestureDetector(
                  onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSize(
                        duration: AppTheme.motion(context, AppTheme.dMed),
                        alignment: Alignment.topCenter,
                        child: Text(
                          lt(l.bio, appLocale),
                          maxLines: _bioExpanded ? null : 4,
                          overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: AppTheme.bodyFont(size: 17, height: 1.45, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(height: AppTheme.s4),
                      Text(
                        _bioExpanded ? L10n.tr('show_less', locale) : L10n.tr('read_more', locale),
                        style: AppTheme.bodyFont(size: 17, weight: FontWeight.w500, color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---- How you compare ----
            SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('how_you_compare', locale))),
            SliverToBoxAdapter(
              child: runsAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                error: (_, _) => _CompareEmpty(locale: locale),
                data: (runs) => _HowYouCompare(legend: l, runs: runs, accent: accent, locale: locale),
              ),
            ),

            // ---- Career ----
            if (l.timeline.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('career_timeline', locale))),
              SliverToBoxAdapter(
                child: IosInsetGroup(
                  dividerIndent: AppTheme.s16 + 56,
                  children: [
                    for (var i = 0; i < l.timeline.length; i++)
                      _TimelineRow(
                        year: l.timeline[i].year,
                        text: lt(l.timeline[i].text, appLocale),
                        accent: accent,
                        isLast: i == l.timeline.length - 1,
                      ),
                  ],
                ),
              ),
            ],

            // ---- Records ----
            if (l.records.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('records', locale))),
              SliverToBoxAdapter(
                child: IosInsetGroup(
                  dividerIndent: AppTheme.s16 + 30 + AppTheme.s12,
                  children: [
                    for (final r in l.records)
                      _IconRow(
                        icon: CupertinoIcons.rosette,
                        iconColor: AppTheme.dawn,
                        text: lt(r, appLocale),
                      ),
                  ],
                ),
              ),
            ],

            // ---- Training philosophy ----
            if (l.trainingPhilosophy != null) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('training_philosophy', locale))),
              SliverToBoxAdapter(
                child: IosInsetGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.s16),
                      child: Text(
                        lt(l.trainingPhilosophy!, appLocale),
                        style: AppTheme.bodyFont(size: 16, height: 1.5, color: cs.onSurface),
                      ),
                    ),
                    if (l.relatedCourseSlug != null)
                      _CourseRow(slug: l.relatedCourseSlug!, locale: appLocale),
                  ],
                ),
              ),
            ],

            // ---- Notable races ----
            if (l.notableRaces != null && l.notableRaces!.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('notable_races', locale))),
              SliverToBoxAdapter(
                child: IosInsetGroup(
                  dividerIndent: AppTheme.s16 + 30 + AppTheme.s12,
                  children: [
                    for (final race in l.notableRaces!)
                      _IconRow(
                        icon: CupertinoIcons.flag_fill,
                        iconColor: accent,
                        text: lt(race, appLocale),
                      ),
                  ],
                ),
              ),
            ],

            // ---- In their words ----
            if (quotes.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('in_their_words', locale))),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 178,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: quotes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s12),
                    itemBuilder: (_, i) => _QuoteCard(
                      text: quotes[i].text,
                      label: quotes[i].label,
                      legend: l,
                    ),
                  ),
                ),
              ),
            ],

            // ---- Fun fact ----
            if (l.funFact != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s28, kIosGutter, 0),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.s16),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppTheme.r16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.dawn.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.lightbulb_fill, size: 20, color: AppTheme.dawn),
                        ),
                        const SizedBox(width: AppTheme.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr('did_you_know_title', locale),
                                style: AppTheme.bodyFont(size: 15, weight: FontWeight.w600, color: cs.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lt(l.funFact!, appLocale),
                                style: AppTheme.bodyFont(size: 15, height: 1.4, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ---- Rivals / related ----
            if (l.rivals.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('rivalries', locale))),
              SliverToBoxAdapter(child: _AvatarStrip(legends: l.rivals, locale: appLocale)),
            ],
            if (l.related.isNotEmpty) ...[
              SliverToBoxAdapter(child: IosSectionHeader(title: L10n.tr('related_legends', locale))),
              SliverToBoxAdapter(child: _AvatarStrip(legends: l.related, locale: appLocale)),
            ],

            if (legendPhotoCredits[l.slug] != null)
              SliverToBoxAdapter(
                child: PhotoCreditLine(credit: legendPhotoCredits[l.slug]!, locale: appLocale),
              ),

            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.s32),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Legend legend;
  final AppLocale locale;
  final double topInset;
  const _Header({required this.legend, required this.locale, required this.topInset});

  @override
  Widget build(BuildContext context) {
    final l = legend;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: legendGradient(l)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fade into the page background at the bottom, like Music artwork.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 0.35)],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(kIosGutter, topInset + kToolbarHeight, kIosGutter, AppTheme.s20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LegendAvatar(legend: l, size: 112, ring: true),
                const SizedBox(height: AppTheme.s16),
                Text(
                  l.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppTheme.bodyFont(size: 32, weight: FontWeight.w800, height: 1.05, color: Colors.white)
                      .copyWith(letterSpacing: -0.9),
                ),
                const SizedBox(height: AppTheme.s6),
                Text(
                  '${l.flag}  ${lt(l.discipline, locale)} · ${lt(l.country, locale)} · ${lt(l.eraLabel, locale)}',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyFont(size: 15, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: AppTheme.s10),
                Text(
                  lt(l.tagline, locale),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White chevron on a dark glass circle, for use over artwork.
class _GlassCircleBack extends StatelessWidget {
  const _GlassCircleBack();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      excludeSemantics: true,
      child: Pressable(
        onTap: () => onAppBack(context),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.chevron_back, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Color.lerp(color, Colors.white, 0.25)! : color;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: () {
          Haptics.light();
          onTap();
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: filled ? color : tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppTheme.r12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : tint),
              const SizedBox(width: AppTheme.s8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: filled ? Colors.white : tint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestTile extends StatelessWidget {
  final String distance;
  final String time;
  const _BestTile({required this.distance, required this.time});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s14, vertical: AppTheme.s12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(distance, style: AppTheme.bodyFont(size: 13, weight: FontWeight.w500, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(time, style: AppTheme.displayFont(size: 26, weight: FontWeight.w700, color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String year;
  final String text;
  final Color accent;
  final bool isLast;
  const _TimelineRow({required this.year, required this.text, required this.accent, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Color.lerp(accent, Colors.white, 0.3)! : accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              year,
              style: AppTheme.monoFont(size: 15, weight: FontWeight.w700, color: tint),
            ),
          ),
          Expanded(
            child: Text(text, style: AppTheme.bodyFont(size: 16, height: 1.35, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  const _IconRow({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: AppTheme.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: AppTheme.bodyFont(size: 16, height: 1.35, color: cs.onSurface)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final String slug;
  final AppLocale locale;
  const _CourseRow({required this.slug, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final course = courseForSlug(slug);
    return Pressable(
      pressedScale: 1,
      onTap: () => context.push('/learn/course/$slug'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: course.category.accent, borderRadius: BorderRadius.circular(8)),
              child: Icon(course.category.icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: AppTheme.s12),
            Expanded(
              child: Text(
                lt(course.title, locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyFont(size: 17, color: cs.onSurface),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final String text;
  final String? label;
  final Legend legend;
  const _QuoteCard({required this.text, required this.label, required this.legend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = legendAccent(legend);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Color.lerp(accent, Colors.white, 0.3)! : accent;
    final width = MediaQuery.sizeOf(context).width * 0.78;
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppTheme.s16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.r16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.quote_bubble_fill, size: 18, color: tint),
              const SizedBox(width: AppTheme.s6),
              Text(
                (label ?? legend.name).toUpperCase(),
                style: AppTheme.bodyFont(size: 12, weight: FontWeight.w700, color: tint).copyWith(letterSpacing: 0.4),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s10),
          Expanded(
            child: Text(
              '“$text”',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyFont(size: 19, weight: FontWeight.w600, height: 1.3, color: cs.onSurface)
                  .copyWith(letterSpacing: -0.3),
            ),
          ),
          Text(
            '— ${legend.name}',
            style: AppTheme.bodyFont(size: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// "Similar artists" style strip of round portraits with names.
class _AvatarStrip extends StatelessWidget {
  final List<Legend> legends;
  final AppLocale locale;
  const _AvatarStrip({required this.legends, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: legends.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s16),
        itemBuilder: (_, i) {
          final r = legends[i];
          return Semantics(
            button: true,
            label: r.name,
            excludeSemantics: true,
            child: Pressable(
              onTap: () => context.push('/legends/${r.slug}'),
              child: SizedBox(
                width: 88,
                child: Column(
                  children: [
                    LegendAvatar(legend: r, size: 80),
                    const SizedBox(height: AppTheme.s8),
                    Text(
                      r.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(size: 13, weight: FontWeight.w500, height: 1.2, color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompareEmpty extends StatelessWidget {
  final AppLocale locale;
  const _CompareEmpty({required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosInsetGroup(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.s20),
          child: Column(
            children: [
              Icon(CupertinoIcons.stopwatch, size: 34, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(height: AppTheme.s8),
              Text(
                L10n.tr('start_running_to_compare', locale),
                textAlign: TextAlign.center,
                style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: cs.onSurface),
              ),
              const SizedBox(height: AppTheme.s4),
              Text(
                L10n.tr('log_distance_to_compare', locale),
                textAlign: TextAlign.center,
                style: AppTheme.bodyFont(size: 15, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.s12),
              FilledButton(
                onPressed: () => context.go('/run'),
                child: Text(L10n.tr('go_for_a_run', locale)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HowYouCompare extends StatelessWidget {
  final Legend legend;
  final List<RunRecord> runs;
  final Color accent;
  final AppLocale locale;
  const _HowYouCompare({required this.legend, required this.runs, required this.accent, required this.locale});

  @override
  Widget build(BuildContext context) {
    // Best run (min duration) per distance bucket.
    final Map<String, int> userPRs = {};
    for (final r in runs) {
      for (final entry in _compareBuckets.entries) {
        if ((r.distanceM - entry.value.meters).abs() <= entry.value.meters * 0.06) {
          final prev = userPRs[entry.key];
          if (prev == null || r.durationMs < prev) userPRs[entry.key] = r.durationMs;
        }
      }
    }

    final rows = <Widget>[];
    for (final entry in _compareBuckets.entries) {
      final legendTime = entry.value.legendKeys
          .map((k) => legend.personalBests?[k])
          .where((v) => v != null)
          .firstOrNull;
      if (legendTime == null) continue;
      rows.add(_CompareRow(
        label: entry.key,
        legendTime: legendTime,
        legendSeconds: _parseTimeToSeconds(legendTime),
        userMs: userPRs[entry.key],
        accent: accent,
        locale: locale,
      ));
    }

    if (rows.isEmpty || userPRs.isEmpty) return _CompareEmpty(locale: locale);
    return IosInsetGroup(children: rows);
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String legendTime;
  final double legendSeconds;
  final int? userMs;
  final Color accent;
  final AppLocale locale;
  const _CompareRow({
    required this.label,
    required this.legendTime,
    required this.legendSeconds,
    required this.userMs,
    required this.accent,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: cs.onSurface);
    final legendStyle = AppTheme.monoFont(size: 15, color: cs.onSurfaceVariant);

    if (userMs == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: titleStyle),
                  Text(
                    L10n.trParams('no_distance_logged', locale, {'label': label}),
                    style: AppTheme.bodyFont(size: 14, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(legendTime, style: legendStyle),
          ],
        ),
      );
    }

    final userSeconds = userMs! / 1000;
    final gapPct = ((userSeconds - legendSeconds) / legendSeconds) * 100;
    final fill = (legendSeconds / userSeconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: titleStyle)),
              Text(formatDuration(userMs!), style: AppTheme.monoFont(size: 15, weight: FontWeight.w600, color: cs.onSurface)),
              Text('  ${L10n.tr('vs', locale)} $legendTime', style: legendStyle),
            ],
          ),
          const SizedBox(height: AppTheme.s8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.rFull),
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: 6,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.s10),
              Text(
                gapPct <= 0 ? L10n.tr('faster', locale) : '+${gapPct.toStringAsFixed(0)}%',
                style: AppTheme.bodyFont(
                  size: 13,
                  weight: FontWeight.w700,
                  color: gapPct <= 0 ? AppTheme.success : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
