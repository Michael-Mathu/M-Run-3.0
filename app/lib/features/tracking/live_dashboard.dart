import 'package:flutter/cupertino.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gps_pipeline/gps_pipeline.dart' show ActivityProfile;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mwendo_app/core/permissions/location_permission.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/core/gamification/gamification_provider.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/network/session_provider.dart';
import 'package:mwendo_app/core/safety/safety_provider.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_app/features/beat/ghost_race_controller.dart';
import 'package:mwendo_app/features/beat/ghost_race_utils.dart';
import 'package:mwendo_app/features/beat/ghost_drawer.dart';
import 'package:mwendo_app/features/challenges/challenge_evaluator.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';
import 'package:mwendo_app/features/safety/safety_service.dart';
import 'package:mwendo_app/features/tracking/tracking_controller.dart';
import 'package:mwendo_app/features/tracking/activity_type_selector.dart';
import 'package:mwendo_app/features/tracking/gps_status_widgets.dart';
import 'package:mwendo_app/features/tracking/recovery_card.dart';
import 'package:mwendo_app/widgets/celebration_overlay.dart';
import 'package:mwendo_app/widgets/glass.dart';
import 'package:mwendo_app/widgets/metric_tile.dart';
import 'package:mwendo_app/widgets/mwendo_map.dart';
import 'package:mwendo_app/design_system/app_permission_card.dart';
import 'package:mwendo_gps_engine/mwendo_gps_engine.dart';
import 'package:go_router/go_router.dart';

class LiveDashboard extends ConsumerStatefulWidget {
  const LiveDashboard({super.key});

  @override
  ConsumerState<LiveDashboard> createState() => _LiveDashboardState();
}

class _LiveDashboardState extends ConsumerState<LiveDashboard> {
  GamifiedChallenge? _celebrate;
  int _lastMilestone = 0;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    // Check location permission once here rather than on every GPS tick.
    // It's re-checked only when a run is started (a relevant event).
    _refreshLocationPermission();
    // Recover a run that was interrupted by a crash/kill.
    ref
        .read(trackingModelProvider.notifier)
        .hasRecoverableRun()
        .then((has) {
      if (has) ref.read(trackingModelProvider.notifier).restoreInterrupted();
    });
  }

  Future<void> _refreshLocationPermission() async {
    final granted = await Permission.location.isGranted;
    if (mounted && granted != _hasLocationPermission) {
      setState(() => _hasLocationPermission = granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(trackingModelProvider);
    final ghostRace = ref.watch(ghostRaceControllerProvider);
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);

    // km milestone haptic
    final km = (m.distanceM / 1000).floor();
    if (km > _lastMilestone && km > 0) {
      _lastMilestone = km;
      Haptics.light();
    }

    final isIdle = m.state == AppEngineState.idle;
    final isRecording = m.state == AppEngineState.recording;

    // Start ghost race when run starts recording
    ref.listen<GhostRaceStateData>(ghostRaceControllerProvider, (prev, next) {
      if (next is GhostRaceArmedData && isRecording) {
        ref.read(ghostRaceControllerProvider.notifier).start();
      }
    });

    // Update ghost race during tracking (throttled to avoid excessive updates)
    ref.listen<TrackingState>(trackingModelProvider, (prev, next) {
      final ghostRace = ref.read(ghostRaceControllerProvider);
      if (ghostRace is GhostRaceRacingData) {
        // Only update when distance or elapsed time change significantly
        final prevDist = prev?.distanceM ?? 0;
        final prevElapsed = prev?.elapsedMs ?? 0;
        if ((next.distanceM - prevDist).abs() < 1 && (next.elapsedMs - prevElapsed) < 500) {
          return; // Skip update - too frequent
        }
        ref.read(ghostRaceControllerProvider.notifier).update(
          userDistanceM: next.distanceM,
          userElapsedMs: next.elapsedMs.toDouble(),
          // Shared, incrementally built list (was a full copy per update).
          routePoints: ref.read(trackingModelProvider.notifier).flatRoute,
        );

        GhostComparisonReliability reliability = GhostComparisonReliability.reliable;
        if (next.lastPointTime != null && DateTime.now().difference(next.lastPointTime!) > const Duration(seconds: 10)) {
          reliability = GhostComparisonReliability.paused;
        } else if (next.currentAccuracy > 10.0) {
          reliability = GhostComparisonReliability.degraded;
        }
        ref.read(ghostRaceControllerProvider.notifier).setReliability(reliability);
      }
    });

    final issueSpace = m.gpsIssue != GpsIssue.none ? kGpsIssueBannerSpace : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Map takes full height when idle, split when recording
              Expanded(
                flex: isIdle ? 100 : 55,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: MwendoMap(
                        // Live lists maintained incrementally by the tracking
                        // controller; the map re-pushes the route only when
                        // routeRevision changes (no per-rebuild O(n) copies).
                        // Segments keep pauses as breaks, not straight jumps.
                        points: ref.read(trackingModelProvider.notifier).flatRoute,
                        segments: ref.read(trackingModelProvider.notifier).mapSegments,
                        routeRevision: ref.read(trackingModelProvider.notifier).routeRevision,
                        previewLocation: m.previewLat == null
                            ? null
                            : latlong.LatLng(m.previewLat!, m.previewLng!),
                        mode: MapMode.live,
                        locationEnabled: _hasLocationPermission,
                        isRecording: isRecording,
                        ghost: ghostRace.maybeWhen(
                          racing: (r) => r.ghost,
                          armed: (g, _) => g,
                          finished: (g) => g.ghost,
                        ),
                        userDistanceM: m.distanceM,
                        raceState: ghostRace.maybeWhen(
                          racing: (r) => GhostRaceState.racing,
                          armed: (_, _) => GhostRaceState.armed,
                          finished: (g) => GhostRaceState.finished,
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + AppTheme.s12,
                      left: AppTheme.s16,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showGpsDetailsSheet(context),
                        child: _StatusPill(
                          state: m.state,
                          accuracy: m.currentAccuracy,
                          gpsAvailable: _hasLocationPermission,
                        ),
                      ),
                    ),
                    if (m.gpsIssue != GpsIssue.none)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + AppTheme.s12 + 48,
                        left: AppTheme.s16,
                        right: AppTheme.s16,
                        child: GpsIssueBanner(issue: m.gpsIssue),
                      ),
                    if (!isIdle)
                      ghostRace.maybeWhen(
                        racing: (racing) => Positioned(
                          top: MediaQuery.of(context).padding.top + AppTheme.s12 + 36 + issueSpace,
                          left: AppTheme.s16,
                          child: _GhostChip(
                            ghost: racing.ghost,
                            m: m,
                            deltaSeconds: racing.deltaSeconds,
                          ),
                        ),
                        armed: (ghost, tier) => Positioned(
                          top: MediaQuery.of(context).padding.top + AppTheme.s12 + 36 + issueSpace,
                          left: AppTheme.s16,
                          child: _GhostChipArmed(ghost: ghost, tier: tier),
                        ),
                        idle: () => const SizedBox.shrink(),
                      ) ?? const SizedBox.shrink(),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + AppTheme.s12,
                      right: AppTheme.s16,
                      child: const _SosButton(),
                    ),
                    // Ghost drawer for live split comparison
                    if (!isIdle) const GhostDrawer(),
                    // Pause Semantics Card
                    if (m.state == AppEngineState.paused)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + AppTheme.s12 + (ghostRace is GhostRaceRacingData ? 72 : 36) + issueSpace,
                        left: AppTheme.s16,
                        right: AppTheme.s16,
                        child: GlassSurface(
                          blur: 0, // over the live map: skip the backdrop blur (perf)
                          borderRadius: BorderRadius.circular(AppTheme.r16),
                          padding: const EdgeInsets.all(AppTheme.s12),
                          child: Row(
                            children: [
                              Icon(Icons.pause_circle_filled_rounded, color: context.tokens.paused),
                              const SizedBox(width: AppTheme.s12),
                              Expanded(
                                child: Text(
                                  L10n.tr('run_paused_hint', locale),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // U-1: the Start button used to be an absolutely-positioned
              // overlay with a fixed offset from the bottom of the screen,
              // sized for a much shorter selector sheet than the current
              // 2x2 activity grid -- it landed visually on top of the
              // Walk/Cycle row instead of below the whole sheet. Rendering
              // it inline right after the selector, inside the same
              // Column, means it can never overlap the grid regardless of
              // how tall the sheet's content is.
              if (isIdle) ...[
                ActivityTypeSelector(
                  selectedProfile: m.profile,
                  onSelected: (profile) {
                    Haptics.light();
                    ref.read(trackingModelProvider.notifier).setProfile(profile);
                  },
                ),
                Container(
                  width: double.infinity,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.s24,
                    AppTheme.s8,
                    AppTheme.s24,
                    MediaQuery.of(context).padding.bottom + AppTheme.s16,
                  ),
                  child: Center(
                    child: _StartButton(
                      onStart: () => _requestAndStart(ref, context),
                    ),
                  ),
                ),
              ],
              // Bottom panel - only show metrics when not idle
              if (!isIdle)
                Expanded(
                  flex: 45,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppTheme.r24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.s24,
                      AppTheme.s20,
                      AppTheme.s24,
                      AppTheme.s16,
                    ),
                    // One hero number (distance) and three secondary metrics,
                    // all tabular, readable at arm's length (Apple Workout
                    // style). Scrolls instead of overflowing at large text.
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: AppTheme.s12),
                          Semantics(
                            label:
                                '${L10n.tr('distance_label', locale)} ${(m.distanceM / 1000).toStringAsFixed(2)}',
                            excludeSemantics: true,
                            child: Column(
                              children: [
                                Text(
                                  (m.distanceM / 1000).toStringAsFixed(2),
                                  style: context.tokens.displayMetric
                                      .copyWith(color: cs.onSurface, height: 1.0),
                                ),
                                Text(
                                  L10n.tr('distance_label', locale),
                                  style: context.tokens.metricLabel
                                      .copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.s16),
                          Row(
                            children: [
                              Expanded(
                                child: MetricTile(
                                  value: formatDuration(m.elapsedMs),
                                  label: L10n.tr('time_label', locale),
                                  align: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: MetricTile(
                                  value: formatPace(m.paceMinPerKm),
                                  label: L10n.tr('pace', locale),
                                  align: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: MetricTile(
                                  value: m.calories.toString(),
                                  label: L10n.tr('calories_label', locale),
                                  align: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.s12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.terrain_rounded,
                                  size: 16, color: cs.onSurfaceVariant),
                              const SizedBox(width: AppTheme.s6),
                              Text(
                                '${m.elevationGainM.toStringAsFixed(0)} m · ${L10n.tr('elev_label', locale)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                          // Room for the floating control bar + tab bar, so no
                          // metric ever sits underneath them.
                          SizedBox(height: MediaQuery.paddingOf(context).bottom + 96),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          if (m.state == AppEngineState.recovering)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + AppTheme.s16,
              left: 0,
              right: 0,
              child: RecoveryCard(
                onResume: () => _requestAndStart(ref, context),
                onDiscard: () => ref.read(trackingModelProvider.notifier).discardRecovery(),
              ),
            )
          // U-1: the idle-state Start button used to be positioned here too
          // (a fixed bottom offset that landed on top of the activity
          // grid) -- it's now rendered inline in the Column right after
          // ActivityTypeSelector instead, so this overlay only needs to
          // handle the recording/paused control bar.
          else if (!isIdle)
            Positioned(
              // paddingOf(...).bottom already includes the floating tab bar
              // (the shell uses extendBody); adding the bar's height again
              // pushed the controls up over the metrics.
              bottom: MediaQuery.paddingOf(context).bottom + AppTheme.s8,
              left: 0,
              right: 0,
              child: _ControlBar(
                isRecording: isRecording,
                onPause: () {
                  Haptics.light();
                  ref.read(trackingModelProvider.notifier).pause();
                },
                onResume: () {
                  Haptics.light();
                  ref.read(trackingModelProvider.notifier).resume();
                },
                onStop: () => _onStop(ref),
              ),
            ),
          if (_celebrate != null)
            CelebrationOverlay(
              title: _celebrate!.title,
              subtitle: 'Challenge complete · +${_celebrate!.xp} XP',
              onDone: () => setState(() => _celebrate = null),
            ),
        ],
      ),
    );
  }

  Future<void> _requestAndStart(WidgetRef ref, BuildContext context) async {
    Haptics.medium();
    final locale = ref.read(localeProvider);
    
    // 1. Foreground Location
    final ok = await ensureLocationPermission(context, ref);
    if (!ok) return;

    // 1b. "Approximate" location (Android 12+ / iOS 14+) counts as granted,
    // but its 1–3 km fixes are all rejected: the run would record no route
    // and no distance. Ask for Precise before starting.
    final tracking = ref.read(trackingModelProvider.notifier);
    await tracking.checkLocationAccuracy();
    if (tracking.diagnostics.permission == 'approximate' && context.mounted) {
      final openSettings = await showCupertinoDialog<bool>(
        context: context,
        builder: (dlg) => CupertinoAlertDialog(
          title: Text(L10n.tr('gps_issue_approximate_title', locale)),
          content: Text(L10n.tr('gps_issue_approximate_body', locale)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dlg).pop(false),
              child: Text(L10n.tr('start_anyway', locale)),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dlg).pop(true),
              child: Text(L10n.tr('open_settings', locale)),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        openAppSettings();
        return;
      }
      if (!context.mounted) return;
    }

    // 2. Notifications (Android 13+)
    final notif = await Permission.notification.status;
    if (!notif.isGranted) {
      final notifResult = await Permission.notification.request();
      if (context.mounted && !notifResult.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.tr('enable_notifications', locale)),
          ),
        );
      }
    }

    // 3. Background Location (Android 11+)
    // We cannot request this concurrently with foreground location.
    // If not granted, explain and let them go to Settings, OR skip.
    if (context.mounted) {
      final bgStatus = await Permission.locationAlways.status;
      if (!context.mounted) return;
      if (!bgStatus.isGranted) {
        final shouldGoToSettings = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: false,
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.s16,
              left: AppTheme.s16,
              right: AppTheme.s16,
              top: AppTheme.s16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTheme.s16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AppPermissionCard(
                  icon: Icons.location_on_rounded,
                  title: L10n.tr('gps_required_title', locale),
                  description: "For reliable tracking when your phone is locked, allow background location. Note: Android will restart the app when you grant this in Settings.",
                  actionLabel: L10n.tr('open_settings', locale),
                  onAction: () {
                    Navigator.of(ctx).pop(true);
                  },
                ),
                const SizedBox(height: AppTheme.s8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(L10n.tr('continue_without_background_location', locale)),
                  ),
                ),
                const SizedBox(height: AppTheme.s8),
              ],
            ),
          ),
        );

        if (shouldGoToSettings == true) {
          openAppSettings();
          // Stop here. The user goes to settings. When they grant the permission,
          // Android will kill and restart the app. They can tap Start Run again.
          return;
        }
      }
    }
    
    // Wait for Android to fully transition the Activity to the foreground state
    // and for the OS to sync the newly granted permissions across its services.
    await Future.delayed(const Duration(milliseconds: 600));
    
    // Enable MapLibre location component AFTER the delay to prevent native SecurityException
    if (mounted) setState(() => _hasLocationPermission = true);
    
    if (mounted) {
      try {
        await ref.read(trackingModelProvider.notifier).start();
      } catch (e) {
        debugPrint('Failed to start GPS engine: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.tr('gps_error_start', locale)),
            ),
          );
        }
        return;
      }
    }
    _refreshLocationPermission();
  }

  void _onStop(WidgetRef ref) async {
    Haptics.heavy();
    // Capture ALL state BEFORE calling stop() which resets to initial.
    final m = ref.read(trackingModelProvider);
    final notifier = ref.read(trackingModelProvider.notifier);
    
    final trackPoints = List<TrackPoint>.from(notifier.points);
    final distanceM = m.distanceM;
    final elapsedMs = m.elapsedMs;
    final movingTimeMs = m.movingTimeMs;
    final elevationGainM = m.elevationGainM;

    final ghostRaceState = ref.read(ghostRaceControllerProvider);
    final ghost = ghostRaceState.maybeWhen(
      racing: (r) => r.ghost,
      armed: (g, _) => g,
      finished: (g) => g.ghost,
    );

    if (m.distanceM < 1) {
      await notifier.stop();
      ref.read(ghostRaceControllerProvider.notifier).reset();
      return;
    }

    var record = notifier.buildRunRecord(switch (m.profile) {
      ActivityProfile.walk => 'Walk',
      ActivityProfile.cycle => 'Ride',
      ActivityProfile.hike => 'Hike',
      ActivityProfile.drive => 'Drive',
      ActivityProfile.indoorPoor => 'Workout',
      _ => 'Run',
    });
    await notifier.stop();
    // Invalidate repository to force all dependent providers to re-read
    ref.invalidate(activityRepositoryProvider);
    ref.invalidate(activitiesProvider);
    ref.invalidate(activityByIdProvider);

    final userAvgPace = distanceM > 0
        ? (elapsedMs / 60000) / (distanceM / 1000)
        : 0.0;
    final newly = ref.read(gamificationProvider.notifier).completeRun(
          distanceM: distanceM,
          durationMs: elapsedMs,
          elevationGainM: elevationGainM,
          avgPaceMinPerKm: userAvgPace,
        );
    // B2: sync to the leaderboard when signed in; anonymous runs stay local.
    final session = ref.read(sessionProvider);
    if (!session.isAnonymous && mounted) {
      final ok = await ref.read(sessionProvider.notifier).submitRun(
        distanceM: distanceM,
        durationMs: elapsedMs,
        movingTimeMs: movingTimeMs,
        elevationGainM: elevationGainM,
        startedAt: trackPoints.isNotEmpty
            ? trackPoints.first.timestamp
            : DateTime.now(),
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.tr('submitted', ref.read(localeProvider)))),
        );
      }
    }

    // Handle ghost race finish
    List<dynamic> newlyGhost = [];
    bool distanceChanged = false;
    
    bool ghostDidNotFinish = false;
    if (ghost != null && ghostRaceState is GhostRaceRacingData) {
      final finalDistanceM = record.distanceM;
      distanceChanged = distanceM > 0 && (finalDistanceM - distanceM).abs() > (distanceM * 0.02);

      // F-3: a "win" previously only compared average pace, with no check
      // that the user actually covered the ghost's distance -- stopping a
      // marathon-ghost race after 150m at a fast pace registered as a full
      // win. Require finishing (within a small GPS/filtering tolerance,
      // matching the 2% band already used for distanceChanged above)
      // before pace is even considered.
      final ghostDistanceM = ghost.distanceKm * 1000;
      final completedDistance = finalDistanceM >= ghostDistanceM * 0.97;
      ghostDidNotFinish = !completedDistance;

      final userAvg = (elapsedMs / 60000) / (finalDistanceM / 1000);
      final beat = completedDistance && userAvg <= ghost.avgPaceMinPerKm;
      newlyGhost = completedDistance
          ? ref.read(gamificationProvider.notifier).recordBeatLegend(ghost, beat)
          : [];

      // Update the record with ghost data before saving (if needed)
      record = record.copyWith(
        ghostId: ghost.id,
        ghostWon: beat,
        ghostRaceVersion: 1,
      );

      // Finish the ghost race controller
      ref.read(ghostRaceControllerProvider.notifier).finish(
        userWon: beat,
        userElapsedMs: elapsedMs,
      );
    }

    // Save the record now that it is fully updated
    var saved = false;
    try {
      final repo = ref.read(activityRepositoryProvider);
      await repo.save(record);
      saved = true;
      debugPrint('Run saved successfully: id=${record.id}, distance=${record.distanceM}m');
    } catch (e, st) {
      debugPrint('Run save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save run')),
        );
      }
    }

    if (mounted) {
      // Post-run OSRM road snapping intentionally not run (see
      // TrackingModel.stop): it uploaded the trace to a car-only demo server.

      // Navigate to results
      if (ghost != null && ghostRaceState is GhostRaceRacingData) {
        final ghostRaceFinal = ref.read(ghostRaceControllerProvider);
        ghostRaceFinal.maybeWhen(
          finished: (finished) {
            GoRouter.of(context).go('/ghost-result/${ghost.id}', extra: {
              'tier': finished.tier.name,
              'won': finished.result == GhostRaceResult.win,
              'didNotFinish': ghostDidNotFinish,
              'elapsedMs': finished.userElapsedMs,
              'recalculated': distanceChanged,
              'splits': finished.splitComparisons.map((s) => {
                'index': s.splitIndex,
                'ghostTime': s.ghostSplitTime,
                'userTime': s.userProjectedSplitTime,
                'delta': s.deltaSeconds,
                'isAhead': s.isAhead,
                'progress': s.progressInSplit,
              }).toList(),
              'routePoints': trackPoints.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
            });
          },
        );
      } else if (saved) {
        // Show the finished run — map with the route, distance, splits.
        // (Before, a normal run was saved silently and the Run screen just
        // reset, so it looked as if nothing had been recorded.)
        GoRouter.of(context).push('/activity/${record.id}');
      }

      if (newlyGhost.isNotEmpty) {
        setState(() => _celebrate = newlyGhost.first);
      } else if (newly.isNotEmpty) {
        setState(() => _celebrate = newly.first);
      }
    }
  }
}

//// Start control for the idle state: one solid tint circle with a label
/// underneath (Apple Workout style). No gradient or glow.
class _StartButton extends ConsumerWidget {
  final VoidCallback onStart;
  const _StartButton({required this.onStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final cs = Theme.of(context).colorScheme;
    // The button names the activity picked above it ("Start walk", ...).
    final profile = ref.watch(trackingModelProvider.select((m) => m.profile));
    final startLabel = L10n.tr(switch (profile) {
      ActivityProfile.walk => 'start_walk',
      ActivityProfile.cycle => 'start_ride',
      ActivityProfile.hike => 'start_hike',
      ActivityProfile.drive => 'start_drive',
      ActivityProfile.indoorPoor => 'start_workout',
      _ => 'start_run',
    }, locale);
    return Semantics(
      button: true,
      label: startLabel,
      excludeSemantics: true,
      child: _AnimatedBounceButton(
        onTap: onStart,
        // Full-width capsule, like the Start button in Apple's Workout app.
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(AppTheme.rFull),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.play_fill, size: 20, color: Colors.white),
              const SizedBox(width: AppTheme.s10),
              Text(
                startLabel,
                style: AppTheme.bodyFont(size: 18, weight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass control bar for recording/paused: Stop (press and hold) · Pause/
/// Resume (big, centre) · a balancing spacer.
class _ControlBar extends ConsumerWidget {
  final bool isRecording;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _ControlBar({
    required this.isRecording,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final tokens = context.tokens;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: GlassSurface(
        blur: 0, // over the live map: skip the backdrop blur (perf)
        borderRadius: BorderRadius.circular(AppTheme.rFull),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s20, vertical: AppTheme.s10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoldToStopButton(
              onStop: onStop,
              label: L10n.tr('stop_run', locale),
              hint: L10n.tr('hold_to_stop', locale),
            ),
            const SizedBox(width: AppTheme.s24),
            Semantics(
              button: true,
              label: isRecording ? L10n.tr('pause_run', locale) : L10n.tr('resume_run', locale),
              excludeSemantics: true,
              child: _AnimatedBounceButton(
                onTap: isRecording ? onPause : onResume,
                child: AnimatedContainer(
                  duration: AppTheme.motion(context, AppTheme.dMed),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isRecording ? tokens.paused : cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRecording ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.s24),
            // Balances the Stop button so Pause sits dead centre.
            const SizedBox(width: 56, height: 56),
          ],
        ),
      ),
    );
  }
}

/// Stop requires a ~0.8 s press-and-hold with a filling ring — a bumped
/// pocket or a sweaty tap can no longer end a run (there was no confirmation
/// before). Screen-reader users get a normal activate action.
class _HoldToStopButton extends StatefulWidget {
  final VoidCallback onStop;
  final String label;
  final String hint;
  const _HoldToStopButton({required this.onStop, required this.label, required this.hint});

  @override
  State<_HoldToStopButton> createState() => _HoldToStopButtonState();
}

class _HoldToStopButtonState extends State<_HoldToStopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _hold.reset();
        widget.onStop();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _begin() {
    Haptics.light();
    _hold.forward();
  }

  void _cancel() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  void _showHint() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(widget.hint),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final red = context.tokens.recording;
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.hint,
      onTap: widget.onStop,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _begin(),
        onTapUp: (_) {
          final early = _hold.value < 1;
          _cancel();
          if (early) _showHint();
        },
        onTapCancel: _cancel,
        child: SizedBox(
          width: 56,
          height: 56,
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _hold.value,
                    strokeWidth: 3,
                    color: red,
                    backgroundColor: red.withValues(alpha: 0.18),
                  ),
                ),
                Transform.scale(
                  scale: 1 - _hold.value * 0.08,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: red, shape: BoxShape.circle),
                    child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass capsule used for all status chips floating over the map.
class _MapChip extends StatelessWidget {
  final Widget child;
  const _MapChip({required this.child});

  @override
  Widget build(BuildContext context) => GlassSurface(
    blur: 0, // over the live map: skip the backdrop blur (perf)
        borderRadius: BorderRadius.circular(AppTheme.rFull),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.s12, vertical: AppTheme.s8),
        child: child,
      );
}

class _StatusPill extends ConsumerWidget {
  final AppEngineState state;
  final double accuracy;
  final bool gpsAvailable;
  const _StatusPill({required this.state, required this.accuracy, this.gpsAvailable = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final tokens = context.tokens;
    final map = {
      AppEngineState.idle: (L10n.tr('ready', locale), tokens.idle),
      AppEngineState.recording: (L10n.tr('recording', locale), tokens.recording),
      AppEngineState.paused: (L10n.tr('paused', locale), tokens.paused),
      AppEngineState.recovering: (L10n.tr('gps_searching', locale), tokens.paused),
    };

    var (label, color) = map[state] ?? (L10n.tr('unknown', locale), tokens.idle);

    // Before a run: live GPS status from the warm-up, so you know when it's
    // safe to start (green = locked, orange = still weak / locating).
    // (A warm-up fix proves permission even before the async check returns.)
    if (state == AppEngineState.idle && (gpsAvailable || accuracy.isFinite)) {
      if (!accuracy.isFinite) {
        color = tokens.warning;
        label = L10n.tr('gps_locating', locale);
      } else if (accuracy <= 15.0) {
        color = AppTheme.success;
        label = L10n.tr('gps_ready', locale);
      } else {
        color = tokens.warning;
        label = L10n.tr('gps_poor', locale);
      }
    }

    // GPS quality while recording: green-ish red dot = good, orange = poor.
    if (state == AppEngineState.recording) {
      if (accuracy <= 10.0) {
        color = tokens.recording;
      } else if (accuracy <= 30.0) {
        color = tokens.warning;
        label = L10n.tr('gps_poor', locale);
      } else {
        color = tokens.paused;
        label = L10n.tr('gps_searching', locale);
      }
    }

    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: _MapChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppTheme.s8),
            Text(label, style: text.labelMedium),
            if (accuracy > 0 && accuracy < 100) ...[
              const SizedBox(width: AppTheme.s6),
              Text(
                '±${accuracy.toStringAsFixed(0)} m',
                style: text.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GhostChip extends ConsumerWidget {
  final GhostPace ghost;
  final TrackingState m;
  final double deltaSeconds;
  const _GhostChip({required this.ghost, required this.m, required this.deltaSeconds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final userAvg = m.distanceM > 0
        ? (m.elapsedMs / 60000) / (m.distanceM / 1000)
        : 0.0;
    final ahead = deltaSeconds < 0 && userAvg > 0;
    // One consistent ahead/behind pair across the app: green / orange.
    final color = ahead ? context.tokens.flagGreen : context.tokens.warning;
    final text = Theme.of(context).textTheme;
    return _MapChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.blur_on_rounded, color: Theme.of(context).colorScheme.onSurface, size: 16),
          const SizedBox(width: AppTheme.s6),
          Text(
            '${L10n.tr('ghost_label', locale)} ${formatPace(ghost.avgPaceMinPerKm)} · you ${userAvg > 0 ? formatPace(userAvg) : "--:--"}',
            style: text.labelMedium,
          ),
          if (userAvg > 0) ...[
            const SizedBox(width: AppTheme.s6),
            Text(
              '${ahead ? "−" : "+"}${formatSeconds(deltaSeconds.abs())}',
              style: text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _GhostChipArmed extends ConsumerWidget {
  final GhostPace ghost;
  final DifficultyTier tier;
  const _GhostChipArmed({required this.ghost, required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return _MapChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tier.badge, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: AppTheme.s6),
          Text(
            '${L10n.tr('ghost_label', locale)} ${tier.label} · ${L10n.tr('ready_to_race', locale)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tier.color),
          ),
        ],
      ),
    );
  }
}

class _SosButton extends ConsumerWidget {
  const _SosButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final red = context.tokens.sos;
    // Clearly labelled and kept at the top of the screen, far from Stop.
    return Semantics(
      button: true,
      label: L10n.tr('sos_button', locale),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _confirmSos(context, ref),
        child: GlassSurface(
          blur: 0, // over the live map: skip the backdrop blur (perf)
          borderRadius: BorderRadius.circular(AppTheme.rFull),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s14, vertical: AppTheme.s10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, color: red, size: 20),
              const SizedBox(width: AppTheme.s6),
              Text('SOS',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: red, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSos(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final cs = Theme.of(context).colorScheme;
    final surface = Theme.of(context).dialogTheme.backgroundColor ?? cs.surface;
    final contacts = ref.read(safetyContactsProvider);
    if (contacts.isEmpty) {
      showAdaptiveDialog(
        context: context,
        builder: (dlg) => AlertDialog.adaptive(
          backgroundColor: surface,
          title: Text(L10n.tr('no_emergency_contacts', locale),
              style: TextStyle(color: cs.onSurface)),
          content: Text(
            L10n.tr('sos_prompt', locale),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlg).pop(),
              child: Text(L10n.tr('ok', locale)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlg) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(dlg).pop();
        },
        child: _SosCountdownDialog(onComplete: () async {
          Navigator.of(dlg).pop();
          final result = await _sendSos(ref);
          if (context.mounted) _showSosOutcome(context, ref, result);
        }),
      ),
    );
  }

  Future<SosResult> _sendSos(WidgetRef ref) async {
    final contacts = ref.read(safetyContactsProvider);
    final notifier = ref.read(trackingModelProvider.notifier);
    final pts = notifier.points;
    final last = pts.isNotEmpty ? pts.last : null;
    final lat = last?.lat ?? kDefaultCenter.latitude;
    final lng = last?.lng ?? kDefaultCenter.longitude;
    return SafetyService.sendSos(contacts, lat, lng);
  }

  // F-1: on-device testing found the previous flow claimed "Sending SOS" /
  // "Alerting contacts" and then, when the SMS composer failed to launch,
  // silently returned to the map with no signal at all -- the worst
  // possible outcome for a safety feature. This surfaces both outcomes
  // honestly: success opens the composer (user still has to tap send, so
  // say that), failure offers a one-tap call to the first contact instead
  // of just failing silently.
  void _showSosOutcome(BuildContext context, WidgetRef ref, SosResult result) {
    final locale = ref.read(localeProvider);
    final cs = Theme.of(context).colorScheme;
    final surface = Theme.of(context).dialogTheme.backgroundColor ?? cs.surface;
    final contacts = ref.read(safetyContactsProvider);

    if (result == SosResult.opened) {
      showAdaptiveDialog(
        context: context,
        builder: (dlg) => AlertDialog.adaptive(
          backgroundColor: surface,
          title: Text(L10n.tr('message_ready_title', locale), style: TextStyle(color: cs.onSurface)),
          content: Text(L10n.tr('sos_opened_body', locale), style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlg).pop(),
              child: Text(L10n.tr('ok', locale)),
            ),
          ],
        ),
      );
      return;
    }

    final firstContact = contacts.isNotEmpty ? contacts.first : null;
    showAdaptiveDialog(
      context: context,
      builder: (dlg) => AlertDialog.adaptive(
        backgroundColor: surface,
        title: Text(L10n.tr('sos_failed_title', locale), style: TextStyle(color: cs.onSurface)),
        content: Text(
          firstContact != null
              ? L10n.trParams('sos_failed_body', locale, {'name': firstContact.name})
              : L10n.tr('sos_prompt', locale),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlg).pop(),
            child: Text(L10n.tr('cancel', locale)),
          ),
          if (firstContact != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.tokens.sos),
              onPressed: () async {
                Navigator.of(dlg).pop();
                final called = await SafetyService.callContact(firstContact);
                if (!called && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(L10n.tr('call_failed', locale))),
                  );
                }
              },
              child: Text(L10n.tr('call_now', locale)),
            ),
        ],
      ),
    );
  }
}

/// Safety-critical SOS countdown: a circular ring that fills red while the
/// number ticks 3 → 2 → 1, escalating amber → orange → red for urgency. Each
/// tick fires a light haptic. Cancelling pops the dialog (timer disposed).
class _SosCountdownDialog extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const _SosCountdownDialog({required this.onComplete});

  @override
  ConsumerState<_SosCountdownDialog> createState() => _SosCountdownDialogState();
}

class _SosCountdownDialogState extends ConsumerState<_SosCountdownDialog> {
  static const int _start = 3;
  int _remaining = _start;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      // Genuine 1-second tick (not a UI animation) — light haptic per second.
      Haptics.light();
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Color _urgency(BuildContext context) {
    final tokens = context.tokens;
    if (_remaining >= 3) return AppTheme.paused; // amber
    if (_remaining == 2) return AppTheme.brand; // orange
    return tokens.sos; // red
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final cs = Theme.of(context).colorScheme;
    final surface = Theme.of(context).dialogTheme.backgroundColor ?? cs.surface;
    final urgency = _urgency(context);
    final progress = (1 - _remaining.clamp(0, _start) / _start).clamp(0.0, 1.0);

    return AlertDialog(
      backgroundColor: surface,
      contentPadding: const EdgeInsets.fromLTRB(
        AppTheme.s24,
        AppTheme.s24,
        AppTheme.s24,
        AppTheme.s16,
      ),
      title: Text(L10n.tr('prepare_sos', locale),
          style: TextStyle(color: cs.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  color: urgency,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.12),
                ),
              ),
              Text(
                '$_remaining',
                style: Theme.of(context)
                    .textTheme
                    .displayMedium!
                    .copyWith(color: urgency, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.s16),
          Text(
            L10n.tr('opening_messages', locale),
            style: TextStyle(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.s20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.tokens.sos,
                foregroundColor: cs.onError,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.s16),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(L10n.tr('cancel', locale)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _AnimatedBounceButton({required this.child, required this.onTap});

  @override
  State<_AnimatedBounceButton> createState() => _AnimatedBounceButtonState();
}

class _AnimatedBounceButtonState extends State<_AnimatedBounceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
