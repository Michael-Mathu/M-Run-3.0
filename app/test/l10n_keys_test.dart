import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';

// Regression test for a whole class of bug found during docs/BUILD_PLAN.md
// UX-6: several screens called L10n.tr('some_key', locale) where 'some_key'
// was never added to app_strings.dart's _strings map. L10n.tr() silently
// falls back to returning the raw key string on a miss (see its
// implementation), so this was never a compile error -- affected users just
// saw literal text like "ghost_held_you_off" or "share" instead of a real
// sentence. Found six of these via a one-off grep sweep; this test makes
// that sweep permanent so a seventh one gets caught in CI instead of
// shipping silently.
void main() {
  test('every L10n.tr(\'key\') / ref.tr(\'key\') call site in app/lib has a defined translation', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run this test from the app/ directory');

    final keyPattern = RegExp(r"""\.tr\(\s*'([a-zA-Z_0-9]+)'""");
    final usedKeys = <String, String>{}; // key -> first file it was found in

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Excludes the definitions file itself -- it never legitimately calls
      // L10n.tr() as a consumer, only defines it, and its own explanatory
      // comments can otherwise produce false-positive matches.
      if (entity.path.endsWith('app_strings.dart')) continue;
      final content = entity.readAsStringSync();
      for (final match in keyPattern.allMatches(content)) {
        final key = match.group(1)!;
        usedKeys.putIfAbsent(key, () => entity.path);
      }
    }

    expect(usedKeys, isNotEmpty, reason: 'sanity check: the scan should have found many L10n.tr(...) call sites');

    final missing = <String>[];
    for (final entry in usedKeys.entries) {
      if (!L10n.hasKey(entry.key)) {
        missing.add('${entry.key} (first used in ${entry.value})');
      }
    }

    expect(missing, isEmpty, reason: 'undefined L10n keys (add them to app_strings.dart\'s _strings map):\n${missing.join('\n')}');
  });
}
