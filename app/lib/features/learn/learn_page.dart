import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/features/learn/data/courses.dart';
import 'package:mwendo_app/widgets/ios.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// The Mwendo Academy, laid out like Apple Books / Podcasts: a large title,
/// then one shelf of course tiles per category.
class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final cs = Theme.of(context).colorScheme;

    return LargeTitlePage(
      title: L10n.tr('learn', locale),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter, 0, kIosGutter, 0),
            child: Text(
              L10n.tr('academy_tag', locale),
              style: AppTheme.bodyFont(size: 15, color: cs.onSurfaceVariant),
            ),
          ),
        ),
        for (final cat in CourseCategory.values)
          if (courses.any((c) => c.category == cat)) ...[
            SliverToBoxAdapter(child: IosSectionHeader(title: lt(cat.label, locale))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 248,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
                  itemCount: courses.where((c) => c.category == cat).length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s12),
                  itemBuilder: (_, i) => _CourseTile(
                    course: courses.where((c) => c.category == cat).elementAt(i),
                    locale: locale,
                  ),
                ),
              ),
            ),
          ],
      ],
    );
  }
}

/// Course "cover": gradient artwork with the category glyph, then title,
/// subtitle and lesson count underneath.
class _CourseTile extends StatelessWidget {
  final Course course;
  final AppLocale locale;
  const _CourseTile({required this.course, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = course.category.accent;
    const width = 220.0;

    return Semantics(
      button: true,
      label: lt(course.title, locale),
      excludeSemantics: true,
      child: Pressable(
        onTap: () {
          Haptics.light();
          context.push('/learn/course/${course.slug}');
        },
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 124,
                width: width,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.12)!,
                      Color.lerp(accent, Colors.black, 0.5)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.r16),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -14,
                      bottom: -18,
                      child: Icon(course.category.icon, size: 112, color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.s12),
                      child: Icon(course.category.icon, size: 26, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                lt(course.title, locale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, height: 1.25, color: cs.onSurface)
                    .copyWith(letterSpacing: -0.3),
              ),
              const SizedBox(height: 2),
              // Flexible so large Dynamic Type sizes clip the subtitle
              // instead of overflowing the fixed-height shelf.
              Flexible(
                child: Text(
                  lt(course.subtitle, locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyFont(size: 14, height: 1.3, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppTheme.s6),
              Text(
                '${course.lessons.length} ${L10n.tr('lessons', locale)} · ${course.minutes} min',
                style: AppTheme.bodyFont(size: 13, weight: FontWeight.w500, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
