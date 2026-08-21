import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/data/models/session_draft.dart';

import 'package:mwendo_app/data/database/app_database.dart';
import 'package:drift/drift.dart' as drift;

final mapMatchJobProvider = Provider<MapMatchJob>((ref) {
  return MapMatchJob(
    ref.read(appDatabaseProvider),
    OsrmMatchProvider(),
  );
});

// ponytail: this job writes matchStatus/matchedDistanceM/smoothedLat/
// smoothedLng onto the SessionDrafts/SessionPoints rows it's given, but
// nothing in the app currently reads those columns back out (checked --
// no repository or screen queries them). It's also fired fire-and-forget
// from TrackingModel.stop() just before the draft row is deleted (crash
// recovery no longer needs it once the run is saved), so most of the time
// this job's writes now land on an already-deleted row and silently no-op.
// Neither behavior is new -- the writes were already unread before the
// crash-recovery fix -- but it means this job is currently dead work.
// Either wire a reader (e.g. show map-matched distance/route on
// route_analysis_screen.dart) or remove the write path; see
// DISCOVERED_ISSUES.md #3.
class MapMatchJob {
  final AppDatabase _db;
  final MatchProvider _provider;

  MapMatchJob(this._db, this._provider);

  Future<void> processSession(SessionDraft draft) async {
    try {
      // 1. Consent check
      // For now, we mock reading matchingConsentGranted from a settings provider.
      // In a real implementation, we would watch or read a user settings provider.
      // final bool matchingConsentGranted = true; // TODO: Read from user settings
      
      /*
      if (!matchingConsentGranted) {
        await _updateStatus(draft.id, MatchStatus.skippedNoConsent.name, null);
        return;
      }
      */

      await _updateStatus(draft.id, MatchStatus.matching.name, null);

      if (!await _provider.isAvailable()) {
        await _updateStatus(draft.id, MatchStatus.unavailable.name, null);
        return;
      }

      // 2. Prepare requests
      final requests = <MatchRequest>[];
      for (final r in draft.filteredResults) {
        requests.add(MatchRequest(
          lat: r.smoothedLat ?? r.raw.lat,
          lng: r.smoothedLng ?? r.raw.lng,
          accuracyM: r.raw.accuracy.toDouble(),
          timestamp: r.raw.timestamp,
        ));
      }

      if (requests.isEmpty) {
        await _updateStatus(draft.id, MatchStatus.rejectedLowQuality.name, null);
        return;
      }

      // 3. Match
      final matchResult = await _provider.match(requests);

      // 4. Quality evaluation
      final quality = MatchQuality.evaluate(draft.filteredResults, matchResult);

      if (!quality.passesThresholds) {
        await _updateStatus(draft.id, MatchStatus.rejectedLowQuality.name, null);
        return;
      }

      // 5. Compute matched distance
      double matchedDistance = 0;
      MatchedPoint? prev;
      for (final p in matchResult.points) {
        if (p != null) {
          if (prev != null) {
            matchedDistance += CoordinateUtil.haversineMetres(prev.lat, prev.lng, p.lat, p.lng);
          }
          prev = p;
        }
      }

      // 6. Persist matched points
      await _persistMatch(draft.id, draft.rawFixes.length, matchResult.points);
      
      // 7. Update status
      await _updateStatus(draft.id, MatchStatus.matched.name, matchedDistance);

    } catch (e) {
      await _updateStatus(draft.id, MatchStatus.failedNetwork.name, null);
    }
  }

  Future<void> _updateStatus(String draftId, String status, double? distance) async {
    await (_db.update(_db.sessionDrafts)
      ..where((d) => d.id.equals(draftId)))
      .write(SessionDraftsCompanion(
        matchStatus: drift.Value(status),
        matchedDistanceM: drift.Value(distance),
      ));
  }

  Future<void> _persistMatch(String draftId, int rawOffset, List<MatchedPoint?> matchedPoints) async {
    await _db.transaction(() async {
      for (int i = 0; i < matchedPoints.length; i++) {
        final p = matchedPoints[i];
        if (p != null) {
          final seq = rawOffset + i;
          await (_db.update(_db.sessionPoints)
                ..where((pt) => pt.draftId.equals(draftId) & pt.seq.equals(seq)))
              .write(SessionPointsCompanion(
            smoothedLat: drift.Value(p.lat),
            smoothedLng: drift.Value(p.lng),
            // We could store snap distance or wayId if we added those columns
          ));
        }
      }
    });
  }
}
