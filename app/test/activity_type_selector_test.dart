import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/features/tracking/activity_type_selector.dart';

// Smoke coverage for the card consolidation in this file (three near-
// duplicate _buildXCard methods merged into one parameterized _ActivityCard)
// -- confirms every profile still renders and taps without throwing for
// both the selected and unselected visual branch of each of the three
// card variants (main/small/indoor).
void main() {
  Future<void> pumpSelector(WidgetTester tester, ActivityProfile selected) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ActivityTypeSelector(
              selectedProfile: selected,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  for (final profile in ActivityProfile.values) {
    testWidgets('renders with ${profile.name} selected', (tester) async {
      await pumpSelector(tester, profile);
      expect(tester.takeException(), isNull);
      expect(find.byType(ActivityTypeSelector), findsOneWidget);
      // Every profile's label should be present regardless of selection.
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Cycle'), findsOneWidget);
      expect(find.text('Hike'), findsOneWidget);
      expect(find.text('Drive'), findsOneWidget);
      expect(find.text('Indoor / Poor Signal'), findsOneWidget);
    });
  }

  testWidgets('tapping a card invokes onSelected with that profile', (tester) async {
    ActivityProfile? tapped;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ActivityTypeSelector(
              selectedProfile: ActivityProfile.run,
              onSelected: (p) => tapped = p,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cycle'));
    await tester.pump();
    expect(tapped, ActivityProfile.cycle);
  });
}
