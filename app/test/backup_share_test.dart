import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/data/backup.dart';
import 'package:mwendo_app/data/models/run_record.dart';
import 'package:mwendo_app/features/activity/share_card.dart';

RunRecord _run(String id, {int points = 5}) {
  final start = DateTime.utc(2026, 11, 16, 5, 30);
  return RunRecord.fromLegacy(
    id: id,
    type: 'Run',
    startedAt: start,
    distanceM: 5021.3,
    durationMs: 1800000,
    movingTimeMs: 1750000,
    calories: 361,
    elevationGainM: 42,
    avgHeartRate: 0,
    avgCadence: 0,
    rawFixes: [
      for (var i = 0; i < points; i++)
        RawFix(
          lat: -1.2921 + i * 0.0001,
          lng: 36.8219 + i * 0.0001,
          elevation: 1700.5,
          timestamp: start.add(Duration(seconds: i)),
          speedMps: 3.2,
          accuracy: 6,
        ),
    ],
  );
}

void main() {
  group('MwendoBackup', () {
    test('round-trips runs and allowed preferences', () {
      final bytes = MwendoBackup.encode(
        runs: [_run('a'), _run('b', points: 0)],
        prefs: {
          'units_mode': 1,
          'run_weight_kg': 64.5,
          'run_voice_cues': false,
          'profile_username': 'Wanjiru',
          'auth_token': 'secret', // not on the allow-list
          'theme_mode_v1': null,
        },
        appVersion: '1.4.0',
        now: DateTime.utc(2026, 11, 16, 6),
      );
      // gzip magic number
      expect(bytes.sublist(0, 2), [0x1f, 0x8b]);

      final back = MwendoBackup.decode(bytes);
      expect(back.createdAt, DateTime.utc(2026, 11, 16, 6));
      expect(back.prefs, {
        'units_mode': 1,
        'run_weight_kg': 64.5,
        'run_voice_cues': false,
        'profile_username': 'Wanjiru',
      });
      expect(back.runs.map((r) => r.id), ['a', 'b']);
      final a = back.runs.first;
      expect(a.type, 'Run');
      expect(a.startedAt.toUtc(), DateTime.utc(2026, 11, 16, 5, 30));
      expect(a.distanceM, 5021.3);
      expect(a.durationMs, 1800000);
      expect(a.movingTimeMs, 1750000);
      expect(a.calories, 361);
      expect(a.elevationGainM, 42);
      expect(a.rawFixes, hasLength(5));
      expect(a.rawFixes[3].lat, closeTo(-1.2918, 1e-9));
      expect(a.rawFixes[3].lng, closeTo(36.8222, 1e-9));
      expect(a.rawFixes[3].elevation, 1700.5);
      expect(a.rawFixes[3].speedMps, 3.2);
      expect(a.rawFixes[3].accuracy, 6);
      expect(a.rawFixes[3].timestamp.toUtc(), DateTime.utc(2026, 11, 16, 5, 30, 3));
      expect(back.runs.last.rawFixes, isEmpty);
    });

    test('the secret never reaches the file', () {
      final bytes = MwendoBackup.encode(
        runs: const [],
        prefs: {'auth_token': 'secret', 'session_email': 'a@b.c'},
        appVersion: '1.4.0',
      );
      final text = utf8.decode(gzip.decode(bytes));
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('a@b.c')));
    });

    test('reads the older plain "Export data" file', () {
      final legacy = utf8.encode(jsonEncode([_run('old', points: 3).toJson()]));
      final back = MwendoBackup.decode(Uint8List.fromList(legacy));
      expect(back.prefs, isEmpty);
      expect(back.runs.single.id, 'old');
      expect(back.runs.single.rawFixes, hasLength(3));
      expect(back.runs.single.distanceM, 5021.3);
    });

    test('skips broken entries but keeps the rest', () {
      final doc = {
        'format': 'mwendo-backup',
        'version': 1,
        'runs': [
          {'id': 'good', 'startedAt': '2026-11-16T05:30:00Z', 'points': [[1, 2], 'x', [-1.2, 36.8, 0, 1000]]},
          {'startedAt': '2026-11-16T05:30:00Z'},
          {'id': 'no-date'},
          42,
        ],
        'prefs': {'units_mode': 'not-checked-here', 'gamification_v1': ['wrong type']},
      };
      final back = MwendoBackup.decode(Uint8List.fromList(utf8.encode(jsonEncode(doc))));
      expect(back.runs.single.id, 'good');
      expect(back.runs.single.rawFixes, hasLength(1));
      expect(back.prefs.keys, ['units_mode']);
    });

    test('rejects files that are not a backup', () {
      expect(() => MwendoBackup.decode(Uint8List(0)), throwsFormatException);
      expect(() => MwendoBackup.decode(Uint8List.fromList(utf8.encode('hello'))),
          throwsFormatException);
      expect(() => MwendoBackup.decode(Uint8List.fromList(utf8.encode('{"format":"other"}'))),
          throwsFormatException);
      expect(
        () => MwendoBackup.decode(
            Uint8List.fromList(utf8.encode('{"format":"mwendo-backup","version":99}'))),
        throwsFormatException,
      );
    });

    test('file name carries the date', () {
      expect(MwendoBackup.fileName(DateTime(2026, 3, 7)), 'mwendo-backup-2026-03-07.mwendo');
    });
  });

  group('share card', () {
    const box = ui.Rect.fromLTWH(100, 200, 800, 600);

    test('fits the route inside the box and keeps its proportions', () {
      // 0.01 degrees north then 0.02 degrees east, at the equator: an L twice
      // as wide as it is tall.
      final lines = projectRoute([
        [(lat: 0.0, lng: 0.0), (lat: 0.01, lng: 0.0), (lat: 0.01, lng: 0.02)],
      ], box);
      final pts = lines.single;
      for (final p in pts) {
        expect(box.inflate(0.001).contains(p), isTrue, reason: '$p');
      }
      final width = pts.last.dx - pts.first.dx;
      final height = pts.first.dy - pts[1].dy;
      expect(width / height, closeTo(2, 0.01));
      // North is up.
      expect(pts[1].dy, lessThan(pts.first.dy));
      // Centred.
      expect((pts.first.dx + pts.last.dx) / 2, closeTo(box.center.dx, 0.5));
    });

    test('keeps separate segments separate and thins long routes', () {
      final long = [for (var i = 0; i < 6000; i++) (lat: i * 0.00001, lng: i * 0.00001)];
      final lines = projectRoute([
        long,
        [(lat: 0.07, lng: 0.07), (lat: 0.08, lng: 0.08)],
      ], box);
      expect(lines, hasLength(2));
      expect(lines.first.length, lessThan(2000));
      expect(lines.last, hasLength(2));
    });

    test('nothing to draw for an empty or stationary route', () {
      expect(projectRoute(const [], box), isEmpty);
      expect(projectRoute([[(lat: 1.0, lng: 1.0)]], box), isEmpty);
      expect(
        projectRoute([[(lat: 1.0, lng: 1.0), (lat: 1.0, lng: 1.0)]], box),
        isEmpty,
      );
    });

    testWidgets('renders a 1080 x 1920 PNG, with and without a route', (tester) async {
      await tester.runAsync(() async {
        // Real fonts, so the saved preview looks like the app's output.
        for (final entry in {
          'Inter': ['Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'],
          'InterDisplay': ['InterDisplay-Bold.ttf', 'InterDisplay-ExtraBold.ttf'],
        }.entries) {
          final loader = FontLoader(entry.key);
          for (final f in entry.value) {
            final file = File('assets/fonts/$f');
            if (file.existsSync()) {
              loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
            }
          }
          await loader.load();
        }

        Future<void> check(ShareCardData data, String name) async {
          final png = await renderShareCard(data);
          expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
          final image = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
          expect(image.width, 1080);
          expect(image.height, 1920);
          final out = Platform.environment['MWENDO_SHARE_PREVIEW_DIR'];
          if (out != null) File('$out/$name.png').writeAsBytesSync(png);
        }

        await check(
          ShareCardData(
            title: 'Run',
            dateLabel: '16/11/2026',
            distanceValue: '5.21',
            distanceUnit: 'km',
            stats: const [
              (label: 'Time', value: '31:04'),
              (label: 'Pace /km', value: '5:58'),
              (label: 'Calories', value: '361'),
            ],
            segments: [
              [
                for (var i = 0; i < 200; i++)
                  (lat: -1.29 + 0.004 * (i / 200) + 0.0012 * ((i ~/ 25) % 2), lng: 36.82 + 0.00006 * i),
              ],
            ],
            footer: 'Tracked with Mwendo',
          ),
          'share-route',
        );
        await check(
          const ShareCardData(
            title: 'Walk',
            dateLabel: '16/11/2026',
            distanceValue: '0.00',
            distanceUnit: 'km',
            stats: [(label: 'Time', value: '00:42')],
            segments: [],
            footer: 'Tracked with Mwendo',
          ),
          'share-empty',
        );
      });
    });
  });
}
