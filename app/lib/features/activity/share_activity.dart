import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/profile/profile_provider.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/data/sample_activities.dart';
import 'package:mwendo_app/features/activity/share_card.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What the share image says about [a], in the user's units and language.
ShareCardData shareCardDataFor(SampleActivity a, {required Units units, required AppLocale locale}) {
  final imperial = units == Units.imperial;
  final unitM = imperial ? 1609.344 : 1000.0;
  final unit = imperial ? 'mi' : 'km';
  final dist = a.distanceM / unitM;
  final hours = a.durationMs / 3600000;

  final type = a.type.toLowerCase();
  final wheels = type.contains('cycl') || type.contains('ride') || type.contains('drive');
  final ({String label, String value}) rate;
  if (wheels) {
    rate = (
      label: '$unit/h',
      value: hours > 0 ? (dist / hours).toStringAsFixed(1) : '--',
    );
  } else {
    rate = (
      label: '${L10n.tr('pace', locale)} /$unit',
      value: formatPace(dist > 0 ? (a.durationMs / 60000) / dist : 0),
    );
  }

  return ShareCardData(
    title: a.type,
    dateLabel: formatDate(a.startedAt.toLocal()),
    distanceValue: dist.toStringAsFixed(dist < 100 ? 2 : 1),
    distanceUnit: unit,
    stats: [
      (label: L10n.tr('time_label', locale), value: formatDuration(a.durationMs)),
      rate,
      if (a.calories > 0)
        (label: L10n.tr('calories_label', locale), value: '${a.calories}')
      else if (a.elevationGainM >= 1)
        (label: L10n.tr('elev_label', locale), value: '${a.elevationGainM.round()} m'),
    ],
    segments: [
      for (final seg in a.routeSegments.isNotEmpty ? a.routeSegments : [a.route])
        [for (final pt in seg) (lat: pt.latitude, lng: pt.longitude)],
    ],
    footer: L10n.tr('share_card_footer', locale),
  );
}

/// Shares [a] as a story-shaped image (route, distance, time, pace) with a
/// one-line caption. Falls back to the caption alone if the image cannot be
/// made, so sharing never fails outright.
Future<void> shareActivity(BuildContext context, WidgetRef ref, SampleActivity a) async {
  final locale = ref.read(localeProvider);
  final units = ref.read(unitsProvider);
  final data = shareCardDataFor(a, units: units, locale: locale);
  final caption = L10n.trParams('share_caption', locale, {
    'distance': '${data.distanceValue} ${data.distanceUnit}',
    'time': formatDuration(a.durationMs),
  });

  XFile? image;
  try {
    final bytes = await renderShareCard(data);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'mwendo-${a.id}.png'));
    await file.writeAsBytes(bytes, flush: true);
    image = XFile(file.path, mimeType: 'image/png');
  } catch (e) {
    debugPrint('Share image failed, sharing text only: $e');
  }
  if (!context.mounted) return;
  await SharePlus.instance.share(
    ShareParams(text: caption, files: image == null ? null : [image]),
  );
}
