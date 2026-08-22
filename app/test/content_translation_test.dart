import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// AUDIT_2.md L-5: guards against new "English-in-disguise" content pairs --
// (en: 'X', sw: 'X') entries in the long-form content data files, where the
// sw field was bulk-copied from en instead of actually translated. This is
// distinct from app_strings.dart's short UI catalog (already covered by
// l10n_keys_test.dart's key-existence check): these are LocalizedText
// (en:, sw:) record literals inside course/legend content.
//
// This starts as a ratcheting threshold, not a hard requirement of zero,
// because as of AUDIT_2.md the real count was 237 untranslated pairs across
// courses.dart/legends.dart -- a translator-scale content task (L-3/L-4),
// not something to gate CI on immediately. The threshold should be lowered
// as translation passes land, and eventually replaced with an exact-zero
// check once the content is fully translated.
void main() {
  test('long-form content files do not gain new untranslated (en==sw) pairs', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run this test from the app/ directory');

    // (en: 'value', sw: 'value') possibly spanning multiple lines, single- or
    // double-quoted, with escaped quotes inside.
    final pat = RegExp(
      r"""en:\s*(['"])((?:\\.|(?!\1).)*)\1\s*,\s*sw:\s*(['"])((?:\\.|(?!\3).)*)\3""",
      dotAll: true,
    );

    const files = [
      'lib/features/learn/data/courses.dart',
      'lib/features/learn/data/legends.dart',
      'lib/features/learn/data/beat_legends.dart',
    ];

    var total = 0;
    var identical = 0;
    final offenders = <String>[];

    for (final path in files) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final content = f.readAsStringSync();
      for (final m in pat.allMatches(content)) {
        total++;
        final en = m.group(2)!;
        final sw = m.group(4)!;
        if (en.trim() == sw.trim() && en.trim().isNotEmpty) {
          identical++;
          if (offenders.length < 10) {
            offenders.add('$path: "${en.length > 60 ? '${en.substring(0, 60)}…' : en}"');
          }
        }
      }
    }

    expect(total, greaterThan(0), reason: 'sanity check: should find many (en:, sw:) content pairs');

    // Ratchet: courses.dart's first two courses (How to Start Running,
    // Heart Rate Zones) were fully translated to real Swahili in a follow-up
    // pass -- tightened from 260 to reflect that progress. The remaining 8
    // courses in courses.dart, plus legends.dart's small handful of real
    // gaps, are still open (tracked in AUDIT_2.md L-3/L-4). Lower this
    // further as more courses are translated.
    const threshold = 235;
    expect(
      identical,
      lessThanOrEqualTo(threshold),
      reason: 'Untranslated (en==sw) content pairs rose to $identical (limit $threshold). '
          'Sample offenders:\n${offenders.join('\n')}\n'
          'See AUDIT_2.md L-3/L-4 -- new lesson/legend content must ship with a real '
          'Swahili translation, not the English text copied into the sw field.',
    );
  });
}
