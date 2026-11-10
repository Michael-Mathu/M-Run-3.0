import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/navigation/navigation.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/features/activity/activity_detail_page.dart';
import 'package:mwendo_app/features/activity/activity_list_page.dart';
import 'package:mwendo_app/features/auth/auth_page.dart';
import 'package:mwendo_app/features/beat/beat_legends_page.dart';
import 'package:mwendo_app/features/beat/ghost_result_screen.dart';
import 'package:mwendo_app/features/challenges/challenge_detail_page.dart';
import 'package:mwendo_app/features/challenges/challenge_library_page.dart';
import 'package:mwendo_app/features/home/dashboard_page.dart';
import 'package:mwendo_app/features/learn/course_detail_page.dart';
import 'package:mwendo_app/features/learn/learn_page.dart';
import 'package:mwendo_app/features/legends/legend_detail_page.dart';
import 'package:mwendo_app/features/legends/legends_home_page.dart';
import 'package:mwendo_app/features/learn/lesson_page.dart';
import 'package:mwendo_app/features/onboarding/onboarding_page.dart';
import 'package:mwendo_app/features/onboarding/onboarding_provider.dart';
import 'package:mwendo_app/features/profile/profile_page.dart' show YouPage;
import 'package:mwendo_app/features/tracking/live_dashboard.dart';
import 'package:mwendo_app/features/tracking/tracking_controller.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/widgets/glass.dart';
import 'package:mwendo_app/widgets/pressable.dart';
import 'package:mwendo_app/features/tracking/route_analysis_screen.dart';

/// Drill-down / full-screen routes use the native push: horizontal slide
/// with parallax and an interactive edge swipe-back on every platform. (The
/// old 6% slide-up + fade made every push look like a modal.)
Page<void> _slidePage(GoRouterState state, Widget child) =>
    CupertinoPage<void>(key: state.pageKey, child: child);

/// Cross-fade transition for tab switches within the [StatefulShellRoute].
/// Tab changes should NOT feel like a push — they dissolve between branches.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
  );
}

GoRouter makeRouter(Ref ref) {
  // Redirect-loop guard: a successful route settlement resets the counter, so
  // a redirect that keeps bouncing (e.g. auth ⇄ onboarding) is capped and
  // falls through to home instead of freezing the app.
  var redirectHops = 0;
  return GoRouter(
    initialLocation: '/',
    observers: [
      _RouteSettledObserver(() => redirectHops = 0),
    ],
    redirect: (context, state) async {
      final done = await ref.read(onboardingDoneProvider.future);
      final loc = state.matchedLocation;
      if (!done && loc != '/onboarding') {
        if (++redirectHops > 10) return '/';
        return '/onboarding';
      }
      if (done && loc == '/onboarding') {
        if (++redirectHops > 10) return '/';
        return '/';
      }
      redirectHops = 0;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ScaffoldWithNavBar(shell: shell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => _fadePage(state, const DashboardPage()),
              ),
            ],
          ),
          // Tab 1: Legends (replaced the placeholder Routes/Explore tab)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/legends',
                pageBuilder: (context, state) => _fadePage(state, const LegendsHomePage()),
              ),
            ],
          ),
          // Tab 2: Track
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/run',
                pageBuilder: (context, state) => _fadePage(state, const LiveDashboard()),
              ),
            ],
          ),
          // Tab 3: Learn
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learn',
                pageBuilder: (context, state) => _fadePage(state, const LearnPage()),
              ),
            ],
          ),
          // Tab 4: You
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/you',
                pageBuilder: (context, state) => _fadePage(state, const YouPage()),
              ),
            ],
          ),
        ],
      ),
      // Standalone routes (outside tabs)
      GoRoute(
        path: '/legends/:slug',
        pageBuilder: (context, state) => _slidePage(
          state,
          LegendDetailPage(slug: state.pathParameters['slug']!),
        ),
      ),
      // Old Explore / Learn → Legends links keep working.
      GoRoute(path: '/explore', redirect: (context, state) => '/legends'),
      GoRoute(
        path: '/learn/course/:slug',
        pageBuilder: (context, state) => _slidePage(
          state,
          CourseDetailPage(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '/learn/course/:slug/lesson/:index',
        pageBuilder: (context, state) => _slidePage(
          state,
          LessonPage(
            slug: state.pathParameters['slug']!,
            index: int.parse(state.pathParameters['index']!),
          ),
        ),
      ),
      GoRoute(path: '/learn/legends', redirect: (context, state) => '/legends'),
      GoRoute(
        path: '/learn/legends/:slug',
        redirect: (context, state) => '/legends/${state.pathParameters['slug']}',
      ),
      GoRoute(
        path: '/beat',
        pageBuilder: (context, state) => _slidePage(state, const BeatLegendsPage()),
      ),
      GoRoute(
        path: '/beat/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          BeatLegendsPage(id: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/activity',
        pageBuilder: (context, state) => _slidePage(state, const ActivityListPage()),
      ),
      GoRoute(
        path: '/activity/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          ActivityDetailPage(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/route-analysis/:id',
        pageBuilder: (context, state) => _slidePage(
          state,
          RouteAnalysisScreen(runId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/challenges',
        pageBuilder: (context, state) => _slidePage(state, const ChallengesLibraryPage()),
      ),
      GoRoute(
        path: '/challenges/:slug',
        pageBuilder: (context, state) => _slidePage(
          state,
          ChallengeDetailPage(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '/ghost-result/:ghostId',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            state,
            GhostResultScreen(
              ghostId: state.pathParameters['ghostId']!,
              tierName: extra['tier'] as String? ?? 'goat',
              userWon: extra['won'] as bool? ?? false,
              didNotFinish: extra['didNotFinish'] as bool? ?? false,
              userElapsedMs: extra['elapsedMs'] as int? ?? 0,
              recalculated: extra['recalculated'] as bool? ?? false,
              splitsJson: jsonEncode(extra['splits'] ?? []),
              routePointsJson: jsonEncode(extra['routePoints'] ?? []),
            ),
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _slidePage(state, const OnboardingPage()),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => _slidePage(state, const AuthPage()),
      ),
    ],
  );
}

/// Resets the redirect-loop counter whenever a route is actually pushed,
/// popped, or replaced, so the cap only trips on genuine redirect storms.
class _RouteSettledObserver extends NavigatorObserver {
  final VoidCallback onSettle;
  _RouteSettledObserver(this.onSettle);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) => onSettle();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previous) => onSettle();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onSettle();
}

final appRouterProvider = Provider<GoRouter>((ref) => makeRouter(ref));

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  const ScaffoldWithNavBar({super.key, required this.shell});

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with WidgetsBindingObserver {
  static const _runTab = 2;
  int? _lastIndex;

  // GPS warm-up policy (see TrackingModel.warmUpGps): a short warm-up at
  // launch / return to the app — most opens end in a run — and a longer one
  // while the Run tab is open, so satellites are locked before Start. Stops
  // when the app is backgrounded (a recording run is unaffected).
  void _warm() {
    final onRun = widget.shell.currentIndex == _runTab;
    ref.read(trackingModelProvider.notifier).warmUpGps(
          duration: onRun ? const Duration(minutes: 3) : const Duration(seconds: 90),
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _warm();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _warm();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      ref.read(trackingModelProvider.notifier).coolDownGps();
    }
  }

  // Swipe-to-switch-tab: detect a horizontal fling on the shell body and move
  // to the adjacent branch. Lightweight alternative to wrapping the shell in a
  // PageView, which would fight StatefulShellRoute's internal navigators.
  static const _branchCount = 5;

  // Tabs that contain horizontal scrollable content should opt out of
  // shell-level swipe navigation to avoid gesture conflicts.
  // Index 1: Legends (horizontal carousels and filter pills)
  // Index 2: Track/Run (live map pans horizontally)
  // Index 3: Learn (horizontal course/lesson cards)
  static const _swipeDisabledIndices = {1, 2, 3}; // Legends, Track/Run, Learn

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_swipeDisabledIndices.contains(widget.shell.currentIndex)) return;
    final v = details.primaryVelocity;
    if (v == null || v.abs() < 300) return;
    final i = widget.shell.currentIndex;
    final next = v < 0 ? i + 1 : i - 1;
    if (next >= 0 && next < _branchCount) widget.shell.goBranch(next);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final index = widget.shell.currentIndex;
    if (index != _lastIndex) {
      final enteredRun = index == _runTab && _lastIndex != null;
      _lastIndex = index;
      // Covers taps and programmatic navigation (e.g. Home's "Go for a run").
      if (enteredRun) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _warm();
        });
      }
    }
    void go(int i) {
      if (i != index) Haptics.selection();
      widget.shell.goBranch(i, initialLocation: i == index);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onAppBack(context);
      },
      child: Scaffold(
        extendBody: true,
        body: GestureDetector(
          onHorizontalDragEnd: _onHorizontalDragEnd,
          behavior: HitTestBehavior.translucent,
          child: widget.shell,
        ),
        bottomNavigationBar: _GlassTabBar(
          currentIndex: index,
          onSelect: go,
          items: [
            _TabItem(CupertinoIcons.house, CupertinoIcons.house_fill, L10n.tr('home', locale)),
            _TabItem(CupertinoIcons.star, CupertinoIcons.star_fill, L10n.tr('legends_title', locale)),
            _TabItem(Icons.directions_run_rounded, Icons.directions_run_rounded,
                L10n.tr('run', locale), isRun: true),
            _TabItem(CupertinoIcons.book, CupertinoIcons.book_fill, L10n.tr('learn', locale)),
            _TabItem(CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill,
                L10n.tr('you', locale)),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isRun;
  const _TabItem(this.icon, this.selectedIcon, this.label, {this.isRun = false});
}

/// Floating "Liquid Glass" tab bar: a translucent capsule inset from the
/// screen edges, filled icon + tint colour for the selected tab (no Material
/// pill indicator), and a solid tint button for Run in the centre.
class _GlassTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<_TabItem> items;

  const _GlassTabBar({
    required this.currentIndex,
    required this.onSelect,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.s16,
        0,
        AppTheme.s16,
        bottomInset > 0 ? bottomInset : AppTheme.s12,
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppTheme.rFull),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: items[i].isRun
                      ? _RunTabButton(
                          label: items[i].label,
                          selected: currentIndex == i,
                          onTap: () => onSelect(i),
                        )
                      : _TabButton(
                          item: items[i],
                          selected: currentIndex == i,
                          onTap: () => onSelect(i),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppTheme.motion(context, AppTheme.dFast),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                key: ValueKey(selected),
                size: 25,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppTheme.bodyFont(
                size: 11,
                weight: selected ? FontWeight.w600 : FontWeight.w500,
                height: 1.1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Run tab: solid tint capsule so the primary action is always findable.
/// Red with a record dot while recording, orange while paused — static, like
/// iOS's recording indicators. (It used to "breathe" with a repeating
/// animation for the whole run, which forced a new frame — and a re-render of
/// the tab bar's glass blur — 60 times a second, costing smoothness and
/// battery during workouts.)
class _RunTabButton extends ConsumerWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RunTabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the engine state, not the whole TrackingState (which changes
    // every second while recording).
    final state = ref.watch(trackingModelProvider.select((m) => m.state));
    final recording = state == AppEngineState.recording;
    final paused = state == AppEngineState.paused;
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final fill = recording
        ? tokens.recording
        : paused
            ? tokens.paused
            : cs.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.92,
        child: Center(
          child: AnimatedContainer(
            duration: AppTheme.motion(context, AppTheme.dMed),
            curve: AppTheme.curveSnappy,
            width: 56,
            height: 48,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppTheme.rFull),
            ),
            child: Icon(
              recording
                  ? Icons.fiber_manual_record_rounded
                  : paused
                      ? Icons.pause_rounded
                      : Icons.directions_run_rounded,
              color: Colors.white,
              size: recording ? 20 : 26,
            ),
          ),
        ),
      ),
    );
  }
}
