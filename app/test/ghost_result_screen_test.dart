import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/features/beat/ghost_result_screen.dart';

// Regression coverage for CQ-2 (the route/split JSON parser was a stub that
// discarded real data) and a bug found while fixing UX-4 (the "ghost held
// you off" headline referenced a localization key that was never defined,
// so a loss showed the literal text "ghost_held_you_off" instead of a real
// sentence).
void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/result',
            routes: [
              GoRoute(path: '/result', builder: (context, state) => child),
              GoRoute(path: '/run', builder: (context, state) => const SizedBox()),
              GoRoute(path: '/beat/:id', builder: (context, state) => const SizedBox()),
            ],
          ),
        ),
      );

  testWidgets('a win shows the real "you beat the ghost" headline', (tester) async {
    await tester.pumpWidget(wrap(const GhostResultScreen(
      ghostId: 'kipchoge-marathon',
      tierName: 'bronze',
      userWon: true,
      userElapsedMs: 9000000,
      splitsJson: '[]',
      routePointsJson: '[]',
    )));
    await tester.pumpAndSettle();

    expect(find.text('You beat the ghost!'), findsOneWidget);
    expect(find.text('ghost_held_you_off'), findsNothing);
  });

  testWidgets('a loss shows a real sentence, not the raw localization key', (tester) async {
    await tester.pumpWidget(wrap(const GhostResultScreen(
      ghostId: 'kipchoge-marathon',
      tierName: 'bronze',
      userWon: false,
      userElapsedMs: 9000000,
      splitsJson: '[]',
      routePointsJson: '[]',
    )));
    await tester.pumpAndSettle();

    expect(find.text('ghost_held_you_off'), findsNothing);
    expect(find.text('The ghost held you off!'), findsOneWidget);
  });

  testWidgets('the loss headline does not overflow at a realistic narrow phone width', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const GhostResultScreen(
      ghostId: 'kipchoge-marathon',
      tierName: 'bronze',
      userWon: false,
      userElapsedMs: 9000000,
      splitsJson: '[]',
      routePointsJson: '[]',
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'the header must not overflow on a real phone-width screen');
  });

  testWidgets('real split data decodes into a populated comparison table, not zero rows', (tester) async {
    final splits = jsonEncode([
      {'index': 0, 'ghostTime': 300.0, 'userTime': 290.0, 'delta': -10.0, 'isAhead': true, 'progress': 1.0},
      {'index': 1, 'ghostTime': 300.0, 'userTime': 310.0, 'delta': 10.0, 'isAhead': false, 'progress': 1.0},
    ]);

    await tester.pumpWidget(wrap(GhostResultScreen(
      ghostId: 'kipchoge-marathon',
      tierName: 'bronze',
      userWon: false,
      userElapsedMs: 600000,
      splitsJson: splits,
      routePointsJson: '[]',
    )));
    await tester.pumpAndSettle();

    // Two split rows means the decode actually populated the table instead
    // of silently defaulting to an empty list (CQ-2's regression).
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
