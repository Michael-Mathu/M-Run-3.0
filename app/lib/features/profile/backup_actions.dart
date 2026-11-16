import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_app/core/gamification/gamification_provider.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/profile/profile_provider.dart';
import 'package:mwendo_app/core/safety/safety_provider.dart';
import 'package:mwendo_app/core/settings/run_settings.dart';
import 'package:mwendo_app/core/theme/palette_provider.dart';
import 'package:mwendo_app/core/theme/theme_mode_provider.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/data/backup.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_gps_engine/mwendo_gps_engine.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastBackup = 'last_backup_at';

/// When the user last made a backup on this phone (null = never).
final lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(_kLastBackup);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
});

// Top-level (not a closure) so `compute` sends only this record to the
// background isolate; a closure would drag the widget context along with it.
Uint8List _encodeBackup(
        ({List<RunRecord> runs, Map<String, Object?> prefs, String appVersion, DateTime now}) a) =>
    MwendoBackup.encode(runs: a.runs, prefs: a.prefs, appVersion: a.appVersion, now: a.now);

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Writes every activity and the user's settings into one file and opens the
/// share sheet, so it can be sent to Drive, WhatsApp, email or another phone.
Future<void> createBackup(BuildContext context, WidgetRef ref, AppLocale locale) async {
  try {
    final runs = await ref.read(activityRepositoryProvider).list();
    final prefs = await SharedPreferences.getInstance();
    final values = <String, Object?>{
      for (final k in MwendoBackup.prefKeys) k: prefs.get(k),
    };
    var appVersion = 'unknown';
    try {
      appVersion = (await MwendoGpsEngine().getPlatformMetadata()).appVersion;
    } catch (_) {}
    final now = DateTime.now();
    // Compressing a long history takes a moment: keep it off the UI thread.
    final bytes = await compute(
      _encodeBackup,
      (runs: runs, prefs: values, appVersion: appVersion, now: now),
    );
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, MwendoBackup.fileName(now)));
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: L10n.tr('backup_share_subject', locale),
      ),
    );
    if (result.status != ShareResultStatus.dismissed) {
      await prefs.setInt(_kLastBackup, now.millisecondsSinceEpoch);
      ref.invalidate(lastBackupProvider);
    }
  } catch (e) {
    debugPrint('Backup failed: $e');
    if (context.mounted) _snack(context, L10n.tr('backup_failed', locale));
  }
}

/// Lets the user pick a backup file and adds its activities to this phone.
///
/// Activities already here are left alone (matched by id), so restoring twice
/// or restoring an old backup never duplicates or overwrites anything.
/// Settings, level and emergency contacts come back only on a phone with no
/// activities yet: on a phone already in use they would replace newer ones.
Future<void> restoreBackup(BuildContext context, WidgetRef ref, AppLocale locale) async {
  final BackupContents backup;
  try {
    final picked = await FilePicker.pickFile();
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    backup = await compute(MwendoBackup.decode, bytes);
  } on FormatException {
    if (context.mounted) _snack(context, L10n.tr('backup_invalid', locale));
    return;
  } catch (e) {
    debugPrint('Restore failed to read the file: $e');
    if (context.mounted) _snack(context, L10n.tr('backup_invalid', locale));
    return;
  }
  if (!context.mounted) return;

  final repo = ref.read(activityRepositoryProvider);
  final existing = await repo.list();
  final have = {for (final r in existing) r.id};
  final fresh = backup.runs.where((r) => !have.contains(r.id)).toList();
  final restoreSettings = existing.isEmpty && backup.prefs.isNotEmpty;

  if (fresh.isEmpty && !restoreSettings) {
    if (context.mounted) _snack(context, L10n.tr('backup_nothing_new', locale));
    return;
  }
  if (!context.mounted) return;

  final made = backup.createdAt;
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (dlg) => CupertinoAlertDialog(
      title: Text(L10n.trParams('backup_restore_title', locale, {'count': '${fresh.length}'})),
      content: Text([
        if (made != null)
          L10n.trParams('backup_made_on', locale, {'date': formatDate(made.toLocal())}),
        L10n.tr(restoreSettings ? 'backup_restore_body_all' : 'backup_restore_body_runs', locale),
      ].join('\n\n')),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dlg).pop(false),
          child: Text(L10n.tr('cancel', locale)),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dlg).pop(true),
          child: Text(L10n.tr('backup_restore_confirm', locale)),
        ),
      ],
    ),
  );
  if (ok != true) return;

  var added = 0;
  for (final run in fresh) {
    try {
      await repo.save(run);
      added++;
    } catch (e) {
      debugPrint('Could not restore activity ${run.id}: $e');
    }
  }

  if (restoreSettings) {
    final prefs = await SharedPreferences.getInstance();
    for (final e in backup.prefs.entries) {
      final v = e.value;
      if (v is String) {
        await prefs.setString(e.key, v);
      } else if (v is bool) {
        await prefs.setBool(e.key, v);
      } else if (v is int) {
        await prefs.setInt(e.key, v);
      } else if (v is double) {
        await prefs.setDouble(e.key, v);
      }
    }
    // Reload everything that reads those preferences.
    ref.invalidate(gamificationProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(unitsProvider);
    ref.invalidate(localeProvider);
    ref.invalidate(safetyContactsProvider);
    ref.invalidate(runSettingsProvider);
    ref.invalidate(themeModeProvider);
    ref.invalidate(paletteProvider);
  }
  ref.invalidate(activitiesProvider);
  ref.invalidate(activityByIdProvider);

  if (context.mounted) {
    _snack(context, L10n.trParams('backup_restored', locale, {'count': '$added'}));
  }
}
