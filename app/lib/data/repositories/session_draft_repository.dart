import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/data/database/app_database.dart';
import 'package:mwendo_app/data/models/session_draft.dart';

final sessionDraftRepositoryProvider = Provider<SessionDraftRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SessionDraftRepository(db);
});

/// The subset of a [SessionDraft] needed to resume an interrupted run.
class RecoverableDraft {
  final String id;
  final List<RawFix> rawFixes;
  final double distanceM;
  final int durationMs;
  final int movingTimeMs;
  final double elevationGainM;
  final ActivityProfile activityType;

  RecoverableDraft({
    required this.id,
    required this.rawFixes,
    required this.distanceM,
    required this.durationMs,
    required this.movingTimeMs,
    required this.elevationGainM,
    required this.activityType,
  });
}

class SessionDraftRepository {
  final AppDatabase _db;

  SessionDraftRepository(this._db);

  Future<void> saveDraft(SessionDraft draft) async {
    await _db.transaction(() async {
      await _db.into(_db.sessionDrafts).insertOnConflictUpdate(SessionDraftsCompanion(
        id: Value(draft.id),
        status: Value(draft.status.name),
        filterVersion: Value(draft.filterVersion.id),
        distanceM: Value(draft.filteredDistanceM),
        durationMs: Value(draft.durationMs),
        movingTimeMs: Value(draft.movingTimeMs),
        elevationGainM: Value(draft.elevationGainM),
        calories: Value(draft.calories),
        createdAt: Value(draft.createdAt),
        matchStatus: Value(draft.matchStatus),
        matchedDistanceM: Value(draft.matchedDistanceM),
        activityType: Value(draft.activityType.name),
        schemaVersion: const Value(4),
      ));

      await (_db.delete(_db.sessionPoints)..where((pt) => pt.draftId.equals(draft.id))).go();

      final pointCompanions = <SessionPointsCompanion>[];

      // Insert raw fixes
      for (int i = 0; i < draft.rawFixes.length; i++) {
        final fix = draft.rawFixes[i];
        pointCompanions.add(SessionPointsCompanion(
          draftId: Value(draft.id),
          seq: Value(i),
          kind: const Value('raw'),
          lat: Value(fix.lat),
          lng: Value(fix.lng),
          elevation: Value(fix.elevation),
          timestamp: Value(fix.timestamp),
          accuracy: Value(fix.accuracy.toInt()),
          hdop: Value(fix.hdop),
          speedMps: Value(fix.speedMps),
          heartRate: Value(fix.heartRate),
          cadence: Value(fix.cadence),
          satelliteCount: Value(fix.satelliteCount),
          provider: Value(fix.provider),
          isMocked: Value(fix.isMocked),
          fixType: Value(fix.fixType),
        ));
      }

      // Insert filtered results
      for (int i = 0; i < draft.filteredResults.length; i++) {
        final result = draft.filteredResults[i];
        final seq = draft.rawFixes.length + i; // Continue sequence
        pointCompanions.add(SessionPointsCompanion(
          draftId: Value(draft.id),
          seq: Value(seq),
          kind: const Value('filtered'),
          lat: Value(result.raw.lat),
          lng: Value(result.raw.lng),
          elevation: Value(result.raw.elevation),
          timestamp: Value(result.raw.timestamp),
          accuracy: Value(result.raw.accuracy.toInt()),
          hdop: Value(result.raw.hdop),
          speedMps: Value(result.raw.speedMps),
          filterStatus: Value(result.isAccepted ? 'accepted' : 'rejected'),
          rejectReason: Value(result.rejectReason?.name),
          smoothedLat: Value(result.smoothedLat),
          smoothedLng: Value(result.smoothedLng),
        ));
      }

      await _db.batch((b) => b.insertAll(_db.sessionPoints, pointCompanions));
    });
  }

  /// Incremental crash-recovery journal: upserts the draft header and appends
  /// [newFixes] at sequence numbers starting at [startSeq] (earlier fixes are
  /// already on disk). Recovery re-derives everything from the raw fixes, so no filtered
  /// results are written here — that keeps each periodic write O(new points)
  /// instead of re-filtering and rewriting the whole run every 10 points.
  ///
  /// Do not mix with [saveDraft] for the same draft mid-run: [saveDraft]
  /// stores filtered rows after the raw ones and would collide with later
  /// appended sequence numbers. (Stop uses [saveDraft] once, after the last
  /// journal write.)
  Future<void> journalDraft({
    required String id,
    required List<RawFix> newFixes,
    required int startSeq,
    required TrackVersion filterVersion,
    required double distanceM,
    required int durationMs,
    required int movingTimeMs,
    required double elevationGainM,
    required int calories,
    required ActivityProfile activityType,
    required DateTime createdAt,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.sessionDrafts).insertOnConflictUpdate(SessionDraftsCompanion(
        id: Value(id),
        status: Value(PostProcessingStatus.pending.name),
        filterVersion: Value(filterVersion.id),
        distanceM: Value(distanceM),
        durationMs: Value(durationMs),
        movingTimeMs: Value(movingTimeMs),
        elevationGainM: Value(elevationGainM),
        calories: Value(calories),
        createdAt: Value(createdAt),
        activityType: Value(activityType.name),
        schemaVersion: const Value(4),
      ));
      if (newFixes.isEmpty) return;
      final rows = <SessionPointsCompanion>[
        for (var j = 0; j < newFixes.length; j++)
          SessionPointsCompanion(
            draftId: Value(id),
            seq: Value(startSeq + j),
            kind: const Value('raw'),
            lat: Value(newFixes[j].lat),
            lng: Value(newFixes[j].lng),
            elevation: Value(newFixes[j].elevation),
            timestamp: Value(newFixes[j].timestamp),
            accuracy: Value(newFixes[j].accuracy.toInt()),
            hdop: Value(newFixes[j].hdop),
            speedMps: Value(newFixes[j].speedMps),
            heartRate: Value(newFixes[j].heartRate),
            cadence: Value(newFixes[j].cadence),
            satelliteCount: Value(newFixes[j].satelliteCount),
            provider: Value(newFixes[j].provider),
            isMocked: Value(newFixes[j].isMocked),
            fixType: Value(newFixes[j].fixType),
          ),
      ];
      // insertOrReplace makes a retried write (same seq) idempotent.
      await _db.batch((b) => b.insertAll(_db.sessionPoints, rows, mode: InsertMode.insertOrReplace));
    });
  }

  /// The most recent draft still awaiting finalization, if any — i.e. a run
  /// interrupted by a crash/kill before `stop()` could delete it.
  Future<RecoverableDraft?> getRecoverable() async {
    final rows = await (_db.select(_db.sessionDrafts)
          ..where((d) => d.status.equals(PostProcessingStatus.pending.name))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    final row = rows.first;

    final pointRows = await (_db.select(_db.sessionPoints)
          ..where((pt) => pt.draftId.equals(row.id) & pt.kind.equals('raw'))
          ..orderBy([(pt) => OrderingTerm.asc(pt.seq)]))
        .get();
    if (pointRows.isEmpty) return null;

    final rawFixes = pointRows
        .map((pt) => RawFix(
              lat: pt.lat,
              lng: pt.lng,
              elevation: pt.elevation,
              timestamp: pt.timestamp,
              speedMps: pt.speedMps,
              accuracy: pt.accuracy,
              hdop: pt.hdop,
              heartRate: pt.heartRate,
              cadence: pt.cadence,
              satelliteCount: pt.satelliteCount,
              provider: pt.provider,
              isMocked: pt.isMocked,
              fixType: pt.fixType ?? 'unknown',
            ))
        .toList();

    ActivityProfile activityType = ActivityProfile.run;
    if (row.activityType != null) {
      for (final p in ActivityProfile.values) {
        if (p.name == row.activityType) {
          activityType = p;
          break;
        }
      }
    }

    return RecoverableDraft(
      id: row.id,
      rawFixes: rawFixes,
      distanceM: row.distanceM,
      durationMs: row.durationMs,
      movingTimeMs: row.movingTimeMs,
      elevationGainM: row.elevationGainM,
      activityType: activityType,
    );
  }

  /// Removes a draft and its points — call once it's been resumed-and-saved
  /// or explicitly discarded, so it stops looking "recoverable."
  Future<void> deleteDraft(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.sessionPoints)..where((pt) => pt.draftId.equals(id))).go();
      await (_db.delete(_db.sessionDrafts)..where((d) => d.id.equals(id))).go();
    });
  }
}
