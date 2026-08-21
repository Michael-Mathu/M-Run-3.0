import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/data/database/app_database.dart';
import 'package:mwendo_app/data/models/session_draft.dart';
import 'package:mwendo_app/data/repositories/session_draft_repository.dart';

// Regression coverage for CQ-1 (crash recovery must actually be readable
// back from the DB, not just written) and the schema-completeness fix
// logged as DISCOVERED_ISSUES.md #1/#2: SessionPoints/SessionDrafts must
// round-trip heartRate/cadence/satelliteCount/provider/isMocked/fixType and
// activityType, not silently drop them on recovery.
void main() {
  late SessionDraftRepository repository;
  late Directory dbDir;

  setUpAll(() async {
    dbDir = await Directory.systemTemp.createTemp('mwendo_draft_db_test');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return dbDir.path;
      },
    );
  });

  tearDownAll(() async {
    final db = AppDatabase();
    await db.close();
    if (await dbDir.exists()) {
      await dbDir.delete(recursive: true);
    }
  });

  setUp(() async {
    final db = AppDatabase();
    try {
      await db.customStatement('DELETE FROM session_points;');
      await db.customStatement('DELETE FROM session_drafts;');
    } catch (_) {}
    repository = SessionDraftRepository(db);
  });

  SessionDraft buildDraft({
    required String id,
    required List<RawFix> rawFixes,
    required ActivityProfile activityType,
  }) {
    final pipeline = GpsPipeline(profile: activityType);
    final filtered = <PipelineResult>[];
    for (final f in rawFixes) {
      final r = pipeline.process(f);
      if (r != null) filtered.add(r);
    }
    filtered.addAll(pipeline.flush());

    return SessionDraft(
      id: id,
      rawFixes: rawFixes,
      filteredResults: filtered,
      filterVersion: TrackVersion.kalmanEkf,
      activityType: activityType,
      filteredDistanceM: 123.4,
      durationMs: 60000,
      movingTimeMs: 55000,
      elevationGainM: 12.0,
      calories: 40,
      status: PostProcessingStatus.pending,
      qualityReport: SessionQualityReport.compute(filtered),
      createdAt: rawFixes.isNotEmpty ? rawFixes.first.timestamp : DateTime.now(),
    );
  }

  test('getRecoverable() returns null when there is no pending draft', () async {
    expect(await repository.getRecoverable(), isNull);
  });

  test('saveDraft() then getRecoverable() round-trips all RawFix fields and activityType', () async {
    final rawFixes = [
      RawFix(
        lat: 1.0,
        lng: 2.0,
        elevation: 10.0,
        timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
        speedMps: 2.5,
        heartRate: 142,
        cadence: 168,
        accuracy: 8,
        hdop: 1.2,
        satelliteCount: 11,
        provider: 'gps',
        isMocked: false,
        fixType: '3d',
      ),
      RawFix(
        lat: 1.001,
        lng: 2.001,
        elevation: 11.0,
        timestamp: DateTime.parse('2026-07-12T09:00:05Z'),
        speedMps: 2.6,
        heartRate: 145,
        cadence: 170,
        accuracy: 8,
        hdop: 1.1,
        satelliteCount: 12,
        provider: 'gps',
        isMocked: false,
        fixType: '3d',
      ),
    ];

    final draft = buildDraft(id: 'draft-1', rawFixes: rawFixes, activityType: ActivityProfile.cycle);
    await repository.saveDraft(draft);

    final recovered = await repository.getRecoverable();
    expect(recovered, isNotNull);
    expect(recovered!.id, 'draft-1');
    expect(recovered.activityType, ActivityProfile.cycle);
    expect(recovered.rawFixes, hasLength(2));

    final r0 = recovered.rawFixes[0];
    expect(r0.lat, rawFixes[0].lat);
    expect(r0.lng, rawFixes[0].lng);
    expect(r0.heartRate, 142);
    expect(r0.cadence, 168);
    expect(r0.satelliteCount, 11);
    expect(r0.provider, 'gps');
    expect(r0.isMocked, false);
    expect(r0.fixType, '3d');
  });

  test('deleteDraft() removes the draft so getRecoverable() returns null afterward', () async {
    final rawFixes = [
      RawFix(
        lat: 1.0,
        lng: 2.0,
        elevation: 10.0,
        timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
        speedMps: 2.5,
        accuracy: 8,
      ),
    ];
    final draft = buildDraft(id: 'draft-2', rawFixes: rawFixes, activityType: ActivityProfile.run);
    await repository.saveDraft(draft);
    expect(await repository.getRecoverable(), isNotNull);

    await repository.deleteDraft('draft-2');
    expect(await repository.getRecoverable(), isNull);
  });
}
