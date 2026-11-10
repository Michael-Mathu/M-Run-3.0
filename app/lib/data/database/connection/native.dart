import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor connect() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'mwendo.db'));
    // SQLite runs on its own background isolate, so queries and writes
    // (loading run history, recovery journaling during a run) never block
    // the UI thread. The isolate lives in the app process, so it keeps
    // working while the foreground tracking service runs with the screen off.
    return NativeDatabase.createInBackground(dbFile);
  });
}
