import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:mwendo_app/data/database/app_database.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:gps_pipeline/gps_pipeline.dart';

import 'package:flutter/services.dart';

// This repository is Drift/SQLite-backed (see AppDatabase.saveRun/getAllRuns/
// getRun/deleteRun) -- these tests exercise that real DB path directly,
// rather than a JSON-file format the repository no longer uses.
void main() {
  late ActivityRepository repository;
  late Directory dbDir;

  setUpAll(() async {
    dbDir = await Directory.systemTemp.createTemp('mwendo_db_test');
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
      await db.customStatement('DELETE FROM activity_points;');
      await db.customStatement('DELETE FROM activities;');
    } catch (_) {}
    repository = ActivityRepository(db);
  });

  test('list() returns empty list when file does not exist', () async {
    final runs = await repository.list();
    expect(runs, isEmpty);
  });

  test('save() writes run record to file and list() retrieves it', () async {
    final run = RunRecord.fromLegacy(
      id: 'test-run-1',
      type: 'Morning Run',
      startedAt: DateTime.parse('2026-07-12T09:00:00Z'),
      distanceM: 5000.0,
      durationMs: 1500000,
      movingTimeMs: 1450000,
      calories: 300,
      elevationGainM: 50.0,
      avgHeartRate: 150,
      avgCadence: 175,
      rawFixes: [
        RawFix(
          lat: 1.0,
          lng: 2.0,
          elevation: 100.0,
          timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
          speedMps: 5.0,
          accuracy: 10,
        ),
        RawFix(
          lat: 1.1,
          lng: 2.1,
          elevation: 105.0,
          timestamp: DateTime.parse('2026-07-12T09:05:00Z'),
          speedMps: 4.8,
          accuracy: 10,
        ),
      ],
    );

    await repository.save(run);

    final runs = await repository.list();
    expect(runs, hasLength(1));
    expect(runs.first.id, 'test-run-1');
    expect(runs.first.type, 'Morning Run');
    expect(runs.first.distanceM, 5000.0);
    expect(runs.first.route.first.latitude, 1.0);
    expect(runs.first.times.first.toUtc().toIso8601String(), '2026-07-12T09:00:00.000Z');
  });

  test('get() retrieves correct run record by id', () async {
    final run1 = RunRecord.fromLegacy(
      id: 'test-run-1',
      type: 'Morning Run',
      startedAt: DateTime.parse('2026-07-12T09:00:00Z'),
      distanceM: 5000.0,
      durationMs: 1500000,
      movingTimeMs: 1450000,
      calories: 300,
      elevationGainM: 50.0,
      avgHeartRate: 150,
      avgCadence: 175,
      rawFixes: [
        RawFix(
          lat: 1.0,
          lng: 2.0,
          elevation: 100.0,
          timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
          speedMps: 5.0,
          accuracy: 10,
        )
      ],
    );
    final run2 = RunRecord.fromLegacy(
      id: 'test-run-2',
      type: 'Evening Run',
      startedAt: DateTime.parse('2026-07-12T18:00:00Z'),
      distanceM: 3000.0,
      durationMs: 900000,
      movingTimeMs: 880000,
      calories: 180,
      elevationGainM: 20.0,
      avgHeartRate: 140,
      avgCadence: 170,
      rawFixes: [
        RawFix(
          lat: 2.0,
          lng: 3.0,
          elevation: 200.0,
          timestamp: DateTime.parse('2026-07-12T18:00:00Z'),
          speedMps: 6.0,
          accuracy: 10,
        )
      ],
    );

    await repository.save(run1);
    await repository.save(run2);

    final retrieved = await repository.get('test-run-2');
    expect(retrieved, isNotNull);
    expect(retrieved!.id, 'test-run-2');
    expect(retrieved.type, 'Evening Run');
  });

  test('delete() removes correct run record', () async {
    final run = RunRecord.fromLegacy(
      id: 'test-run-1',
      type: 'Morning Run',
      startedAt: DateTime.parse('2026-07-12T09:00:00Z'),
      distanceM: 5000.0,
      durationMs: 1500000,
      movingTimeMs: 1450000,
      calories: 300,
      elevationGainM: 50.0,
      avgHeartRate: 150,
      avgCadence: 175,
      rawFixes: [
        RawFix(
          lat: 1.0,
          lng: 2.0,
          elevation: 100.0,
          timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
          speedMps: 5.0,
          accuracy: 10,
        )
      ],
    );

    await repository.save(run);
    expect(await repository.list(), isNotEmpty);

    await repository.delete('test-run-1');
    expect(await repository.list(), isEmpty);
  });

  test('save() with an empty rawFixes list stores a run with empty route/elevation/pace/times', () async {
    final run = RunRecord.fromLegacy(
      id: 'empty-run-1',
      type: 'Morning Run',
      startedAt: DateTime.parse('2026-07-12T09:00:00Z'),
      distanceM: 0.0,
      durationMs: 0,
      movingTimeMs: 0,
      calories: 0,
      elevationGainM: 0.0,
      avgHeartRate: 0,
      avgCadence: 0,
      rawFixes: const [],
    );

    await repository.save(run);

    final runs = await repository.list();
    expect(runs, hasLength(1));
    expect(runs.first.id, 'empty-run-1');
    expect(runs.first.route, isEmpty);
    expect(runs.first.elevation, isEmpty);
    expect(runs.first.pace, isEmpty);
    expect(runs.first.times, isEmpty);
  });

  test('save() called twice with the same id replaces the run and its points', () async {
    final first = RunRecord.fromLegacy(
      id: 'replace-run-1',
      type: 'Morning Run',
      startedAt: DateTime.parse('2026-07-12T09:00:00Z'),
      distanceM: 1000.0,
      durationMs: 300000,
      movingTimeMs: 290000,
      calories: 60,
      elevationGainM: 5.0,
      avgHeartRate: 130,
      avgCadence: 160,
      rawFixes: [
        RawFix(
          lat: 1.0,
          lng: 2.0,
          elevation: 100.0,
          timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
          speedMps: 3.0,
          accuracy: 10,
        ),
        RawFix(
          lat: 1.05,
          lng: 2.05,
          elevation: 101.0,
          timestamp: DateTime.parse('2026-07-12T09:01:00Z'),
          speedMps: 3.0,
          accuracy: 10,
        ),
      ],
    );
    await repository.save(first);

    final replacement = RunRecord.fromLegacy(
      id: 'replace-run-1',
      type: 'Evening Run',
      startedAt: DateTime.parse('2026-07-12T09:00:00Z'),
      distanceM: 5000.0,
      durationMs: 1500000,
      movingTimeMs: 1450000,
      calories: 300,
      elevationGainM: 50.0,
      avgHeartRate: 150,
      avgCadence: 175,
      rawFixes: [
        RawFix(
          lat: 9.0,
          lng: 9.0,
          elevation: 200.0,
          timestamp: DateTime.parse('2026-07-12T09:00:00Z'),
          speedMps: 5.0,
          accuracy: 10,
        ),
      ],
    );
    await repository.save(replacement);

    final runs = await repository.list();
    expect(runs, hasLength(1));
    expect(runs.first.id, 'replace-run-1');
    expect(runs.first.type, 'Evening Run');
    expect(runs.first.distanceM, 5000.0);
    // The first run's second point must not linger after the replacement's
    // batch insert -- this is what saveRun's delete-then-insert (now inside
    // one transaction) is responsible for.
    expect(runs.first.route, hasLength(1));
    expect(runs.first.route.first.latitude, 9.0);
  });
}
