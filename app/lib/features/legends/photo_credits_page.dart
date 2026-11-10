import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/features/learn/data/legends.dart';
import 'package:mwendo_app/features/legends/legend_photos.dart';
import 'package:mwendo_app/features/legends/legend_widgets.dart';
import 'package:mwendo_app/widgets/ios.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Opens a photo's Wikimedia Commons page (author, licence, original file).
Future<void> openPhotoSource(LegendPhotoCredit c) async {
  final uri = Uri.parse(c.sourceUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Attribution for every bundled legend photo, as their licences require.
class PhotoCreditsPage extends ConsumerWidget {
  const PhotoCreditsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final appLocale = locale == AppLocale.swahili ? AppLocale.swahili : AppLocale.english;
    final cs = Theme.of(context).colorScheme;
    final credited = legends.where((l) => legendPhotoCredits.containsKey(l.slug)).toList();

    return LargeTitlePage(
      title: L10n.tr('photo_credits', locale),
      showBack: true,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kIosGutter, 0, kIosGutter, AppTheme.s16),
            child: Text(
              L10n.tr('photo_credits_note', locale),
              style: AppTheme.bodyFont(size: 15, height: 1.4, color: cs.onSurfaceVariant),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: IosInsetGroup(
            dividerIndent: AppTheme.s16 + 40 + AppTheme.s12,
            children: [
              for (final l in credited)
                _CreditRow(legend: l, credit: legendPhotoCredits[l.slug]!, locale: appLocale),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditRow extends StatelessWidget {
  final Legend legend;
  final LegendPhotoCredit credit;
  final AppLocale locale;
  const _CreditRow({required this.legend, required this.credit, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${legend.name}: ${credit.author}, ${credit.licence}',
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 1,
        onTap: () => openPhotoSource(credit),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s10),
          child: Row(
            children: [
              LegendAvatar(legend: legend, size: 40),
              const SizedBox(width: AppTheme.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(legend.name,
                        style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: cs.onSurface)),
                    Text(
                      '${credit.author} · ${credit.licence}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(size: 14, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.arrow_up_right_square, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small "Photo: author · licence · Wikimedia Commons" line for a legend page.
class PhotoCreditLine extends StatelessWidget {
  final LegendPhotoCredit credit;
  final AppLocale locale;
  const PhotoCreditLine({super.key, required this.credit, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      pressedScale: 1,
      onTap: () => openPhotoSource(credit),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s28, kIosGutter, 0),
        child: Text(
          '${L10n.tr('photo_label', locale)}: ${credit.author} · ${credit.licence} · Wikimedia Commons',
          style: AppTheme.bodyFont(size: 12, height: 1.4, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
