import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:gps_pipeline/gps_pipeline.dart';

import 'models/run_record.dart';

/// A full copy of what Mwendo keeps on the phone, as one file the user can
/// send anywhere (Drive, WhatsApp, email) and restore on another phone.
///
/// Runs live only on the device. Phones get lost, stolen and replaced, and a
/// lost history is a lost runner, so this is the safety net until there are
/// accounts.
///
/// Format: gzip-compressed JSON.
///
/// ```json
/// { "format": "mwendo-backup", "version": 1, "createdAt": "…", "app": "1.4.0",
///   "runs": [ { "id": "…", "type": "Run", "startedAt": "…", "distanceM": 5021.3,
///               "durationMs": 1800000, "movingTimeMs": 1750000, "calories": 361,
///               "elevationGainM": 42, "avgHeartRate": 0, "avgCadence": 0,
///               "points": [[lat, lng, elevation, epochMs, speedMps, accuracyM], …] } ],
///   "prefs": { "units_mode": 0, "gamification_v1": "…" } }
/// ```
///
/// Points are positional arrays rather than objects: an hour of running is
/// 3,600 fixes, and repeating six key names in each roughly triples the file.
class MwendoBackup {
  const MwendoBackup._();

  static const String format = 'mwendo-backup';
  static const int version = 1;

  /// Preference keys that are part of a backup. An allow-list, so sign-in
  /// tokens, the profile photo path (a file on the old phone) and
  /// device-specific flags are never copied.
  static const List<String> prefKeys = [
    'profile_username',
    'units_mode',
    'mwendo.locale',
    'theme_mode_v1',
    'color_palette',
    'gamification_v1',
    'safety_contacts_v1',
    'run_weight_kg',
    'run_auto_pause',
    'run_voice_cues',
    'onboarding_done',
  ];

  /// File name for a backup made at [now], e.g. `mwendo-backup-2026-11-16.mwendo`.
  static String fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'mwendo-backup-${now.year}-${two(now.month)}-${two(now.day)}.mwendo';
  }

  static Uint8List encode({
    required List<RunRecord> runs,
    required Map<String, Object?> prefs,
    required String appVersion,
    DateTime? now,
  }) {
    final doc = <String, Object?>{
      'format': format,
      'version': version,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'app': appVersion,
      'runs': runs.map(_runToJson).toList(growable: false),
      'prefs': {
        for (final k in prefKeys)
          if (prefs[k] != null) k: prefs[k],
      },
    };
    return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(doc))));
  }

  static Map<String, Object?> _runToJson(RunRecord r) => {
        'id': r.id,
        'type': r.type,
        'startedAt': r.startedAt.toUtc().toIso8601String(),
        'distanceM': r.distanceM,
        'durationMs': r.durationMs,
        'movingTimeMs': r.movingTimeMs,
        'calories': r.calories,
        'elevationGainM': r.elevationGainM,
        'avgHeartRate': r.avgHeartRate,
        'avgCadence': r.avgCadence,
        'points': [
          for (final f in r.rawFixes)
            [
              f.lat,
              f.lng,
              f.elevation,
              f.timestamp.millisecondsSinceEpoch,
              f.speedMps,
              f.accuracy,
            ],
        ],
      };

  /// Reads a backup file. Also accepts the older "Export data" file (a plain
  /// JSON list of runs). Throws [FormatException] if it is neither.
  static BackupContents decode(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('Empty file');
    final isGzip = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    final Object? doc;
    try {
      doc = jsonDecode(utf8.decode(isGzip ? gzip.decode(bytes) : bytes));
    } catch (_) {
      throw const FormatException('Not a Mwendo backup');
    }

    if (doc is List) {
      // Legacy export: [ RunRecord.toJson(), … ]
      return BackupContents(
        runs: [for (final r in doc) if (r is Map) ?_runFromJson(r)],
        prefs: const {},
        createdAt: null,
      );
    }
    if (doc is! Map || doc['format'] != format) {
      throw const FormatException('Not a Mwendo backup');
    }
    final v = doc['version'];
    if (v is! int || v > version) {
      throw const FormatException('This backup was made by a newer version of Mwendo');
    }
    final runs = doc['runs'];
    final prefs = doc['prefs'];
    return BackupContents(
      runs: [
        if (runs is List)
          for (final r in runs)
            if (r is Map) ?_runFromJson(r),
      ],
      prefs: {
        if (prefs is Map)
          for (final k in prefKeys)
            if (_isPrefValue(prefs[k])) k: prefs[k] as Object,
      },
      createdAt: DateTime.tryParse('${doc['createdAt']}'),
    );
  }

  static bool _isPrefValue(Object? v) => v is String || v is int || v is double || v is bool;

  /// One run, or null if the entry is unusable (it is skipped, the rest of
  /// the backup still restores).
  static RunRecord? _runFromJson(Map<dynamic, dynamic> j) {
    final id = j['id'];
    final started = DateTime.tryParse('${j['startedAt']}');
    if (id is! String || id.isEmpty || started == null) return null;
    final fixes = <RawFix>[];
    final points = j['points'];
    if (points is List) {
      for (final p in points) {
        if (p is! List || p.length < 4) continue;
        final lat = p[0], lng = p[1], ele = p[2], t = p[3];
        if (lat is! num || lng is! num || t is! num) continue;
        fixes.add(RawFix(
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          elevation: ele is num ? ele.toDouble() : 0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
          speedMps: p.length > 4 && p[4] is num ? (p[4] as num).toDouble() : 0,
          accuracy: p.length > 5 && p[5] is num ? (p[5] as num).toInt() : 10,
        ));
      }
    } else if (j['rawFixes'] is List) {
      // Legacy export shape.
      for (final f in j['rawFixes'] as List) {
        if (f is! Map) continue;
        final lat = f['lat'], lng = f['lng'];
        final t = DateTime.tryParse('${f['timestamp']}');
        if (lat is! num || lng is! num || t == null) continue;
        fixes.add(RawFix(
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          elevation: f['elevation'] is num ? (f['elevation'] as num).toDouble() : 0,
          timestamp: t,
          speedMps: f['speedMps'] is num ? (f['speedMps'] as num).toDouble() : 0,
          accuracy: f['accuracy'] is num ? (f['accuracy'] as num).toInt() : 10,
        ));
      }
    }
    double d(String k) => j[k] is num ? (j[k] as num).toDouble() : 0;
    int i(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    final duration = i('durationMs');
    return RunRecord.fromLegacy(
      id: id,
      type: j['type'] is String ? j['type'] as String : 'Run',
      startedAt: started,
      distanceM: d('distanceM'),
      durationMs: duration,
      movingTimeMs: i('movingTimeMs') > 0 ? i('movingTimeMs') : duration,
      calories: i('calories'),
      elevationGainM: d('elevationGainM'),
      avgHeartRate: i('avgHeartRate'),
      avgCadence: i('avgCadence'),
      rawFixes: fixes,
    );
  }
}

class BackupContents {
  final List<RunRecord> runs;
  final Map<String, Object> prefs;
  final DateTime? createdAt;

  const BackupContents({required this.runs, required this.prefs, required this.createdAt});
}
