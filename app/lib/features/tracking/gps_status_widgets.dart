import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gps_pipeline/gps_pipeline.dart' show RejectReason;
import 'package:permission_handler/permission_handler.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/features/tracking/tracking_controller.dart';

/// Height reserved under the status pill while [GpsIssueBanner] is showing,
/// so chips placed below the pill move down instead of overlapping it.
const double kGpsIssueBannerSpace = 84;

/// Explains why a run isn't recording a route — "Approximate" location, GPS
/// failing to start, no fixes, or a mock-location app — with a way to fix it.
class GpsIssueBanner extends ConsumerWidget {
  final GpsIssue issue;
  const GpsIssueBanner({super.key, required this.issue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final (title, body, icon, color) = switch (issue) {
      GpsIssue.approximate => (
          'gps_issue_approximate_title',
          'gps_issue_approximate_body',
          CupertinoIcons.location_slash_fill,
          context.tokens.warning,
        ),
      GpsIssue.startFailed => (
          'gps_issue_start_failed_title',
          'gps_issue_start_failed_body',
          CupertinoIcons.exclamationmark_triangle_fill,
          context.tokens.recording,
        ),
      GpsIssue.noSignal => (
          'gps_issue_no_signal_title',
          'gps_issue_no_signal_body',
          CupertinoIcons.antenna_radiowaves_left_right,
          context.tokens.warning,
        ),
      GpsIssue.mocked => (
          'gps_issue_mocked_title',
          'gps_issue_mocked_body',
          CupertinoIcons.exclamationmark_triangle_fill,
          context.tokens.warning,
        ),
      GpsIssue.none => ('', '', CupertinoIcons.location, context.tokens.idle),
    };
    if (issue == GpsIssue.none) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final needsSettings = issue == GpsIssue.approximate || issue == GpsIssue.startFailed;

    return Semantics(
      liveRegion: true,
      // Solid (not glass): this is a warning people must be able to read over
      // a busy map.
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkElevated
              : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.r16),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(AppTheme.s12, AppTheme.s10, AppTheme.s4, AppTheme.s10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppTheme.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(L10n.tr(title, locale),
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    L10n.tr(body, locale),
                    style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (needsSettings)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8),
                minimumSize: const Size(44, 44),
                onPressed: () => openAppSettings(),
                child: Text(
                  L10n.tr('gps_fix_button', locale),
                  style: text.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: () => ref.read(trackingModelProvider.notifier).clearGpsIssue(),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "GPS details" sheet (tap the status pill): how many fixes arrived, how many
/// were used, why the rest were rejected, and the permission level. If a run
/// records no route, this says why.
Future<void> showGpsDetailsSheet(BuildContext context) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => const _GpsDetailsSheet(),
  );
}

class _GpsDetailsSheet extends ConsumerStatefulWidget {
  const _GpsDetailsSheet();

  @override
  ConsumerState<_GpsDetailsSheet> createState() => _GpsDetailsSheetState();
}

class _GpsDetailsSheetState extends ConsumerState<_GpsDetailsSheet> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    ref.read(trackingModelProvider.notifier).checkLocationAccuracy();
    // The counters aren't reactive state (counting must not rebuild the run
    // screen), so the open sheet refreshes itself once a second.
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  String _reason(RejectReason r, AppLocale locale) => L10n.tr(switch (r) {
        RejectReason.poorAccuracy || RejectReason.zeroAccuracy => 'gps_reject_accuracy',
        RejectReason.stationary => 'gps_reject_stationary',
        RejectReason.spikeDetected ||
        RejectReason.excessiveSpeed ||
        RejectReason.largeInnovation =>
          'gps_reject_jump',
        RejectReason.mocked => 'gps_reject_mocked',
        _ => 'gps_reject_other',
      }, locale);

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final m = ref.watch(trackingModelProvider);
    final d = ref.read(trackingModelProvider.notifier).diagnostics;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final cs = theme.colorScheme;

    final reasons = <String, int>{};
    d.rejected.forEach((r, n) {
      final k = _reason(r, locale);
      reasons[k] = (reasons[k] ?? 0) + n;
    });

    String ago(DateTime? t) {
      if (t == null) return '—';
      final s = DateTime.now().difference(t).inSeconds;
      return L10n.trParams('gps_seconds_ago', locale, {'n': '$s'});
    }

    final permission = switch (d.permission) {
      'precise' => L10n.tr('gps_precise', locale),
      'approximate' => L10n.tr('gps_approximate', locale),
      'none' => L10n.tr('gps_not_allowed', locale),
      _ => '—',
    };
    final isIdle = m.state == AppEngineState.idle;

    final rows = <(String, String, Color?)>[
      (L10n.tr('gps_permission', locale), permission,
          d.permission == 'precise' ? null : context.tokens.warning),
      (
        L10n.tr('gps_last_accuracy', locale),
        m.currentAccuracy.isFinite ? '±${m.currentAccuracy.toStringAsFixed(0)} m' : '—',
        null,
      ),
      if (!isIdle) ...[
        (L10n.tr('gps_fixes_received', locale), '${d.rawFixes}', d.rawFixes == 0 ? context.tokens.warning : null),
        (L10n.tr('gps_fixes_used', locale), '${d.accepted}', null),
        (L10n.tr('gps_fixes_rejected', locale), '${d.rejectedTotal}', null),
        (L10n.tr('gps_last_fix', locale), ago(d.lastFixAt), null),
        (L10n.tr('gps_source', locale), d.lastProvider ?? '—', null),
      ],
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(AppTheme.s8),
        padding: const EdgeInsets.fromLTRB(AppTheme.s20, AppTheme.s16, AppTheme.s20, AppTheme.s16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.r24),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(L10n.tr('gps_details', locale), style: text.titleLarge)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(CupertinoIcons.xmark_circle_fill, color: cs.onSurfaceVariant, size: 28),
                  ),
                ],
              ),
              Text(
                L10n.tr(isIdle ? 'gps_details_hint_idle' : 'gps_details_hint', locale),
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.s12),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.s10),
                  child: Row(
                    children: [
                      Expanded(child: Text(rows[i].$1, style: text.bodyMedium)),
                      Text(
                        rows[i].$2,
                        style: text.bodyMedium?.copyWith(
                          color: rows[i].$3 ?? cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: AppTheme.s12),
                Text(L10n.tr('gps_reject_reasons', locale),
                    style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppTheme.s4),
                for (final e in reasons.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: text.bodySmall)),
                        Text('${e.value}', style: text.bodySmall),
                      ],
                    ),
                  ),
              ],
              if (d.lastError != null) ...[
                const SizedBox(height: AppTheme.s12),
                Text(d.lastError!, style: text.bodySmall?.copyWith(color: context.tokens.recording)),
              ],
              if (d.permission == 'approximate' || d.permission == 'none') ...[
                const SizedBox(height: AppTheme.s16),
                CupertinoButton.filled(
                  onPressed: () => openAppSettings(),
                  child: Text(L10n.tr('open_settings', locale)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
