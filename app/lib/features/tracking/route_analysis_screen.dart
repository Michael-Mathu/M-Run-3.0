import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/data/repositories/activity_repository.dart';
import 'package:mwendo_app/widgets/mwendo_map.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/data/models/run_record.dart';

enum MapLayer { raw, filtered, matched }

class RouteAnalysisScreen extends ConsumerStatefulWidget {
  final String runId;

  const RouteAnalysisScreen({super.key, required this.runId});

  @override
  ConsumerState<RouteAnalysisScreen> createState() => _RouteAnalysisScreenState();
}

class _RouteAnalysisScreenState extends ConsumerState<RouteAnalysisScreen> {
  bool _isLoading = true;
  RunRecord? _run;
  SessionQualityReport? _report;

  MapLayer _selectedLayer = MapLayer.filtered;

  @override
  void initState() {
    super.initState();
    _loadAndProcess();
  }

  Future<void> _loadAndProcess() async {
    final repo = ref.read(activityRepositoryProvider);
    final run = await repo.get(widget.runId);
    if (run == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final pipeline = GpsPipeline(profile: ActivityProfile.run);
    final results = await pipeline.reprocessAsync(run.rawFixes);

    _report = SessionQualityReport.compute(results);

    if (mounted) {
      setState(() {
        _run = run;
        _isLoading = false;
        if (run.matchedResults != null && run.matchedResults!.isNotEmpty) {
          _selectedLayer = MapLayer.matched;
        }
      });
    }
  }

  List<latlong.LatLng> _getPointsForLayer() {
    if (_run == null) return [];

    switch (_selectedLayer) {
      case MapLayer.raw:
        return _run!.rawFixes.map((f) => latlong.LatLng(f.lat, f.lng)).toList();
      case MapLayer.filtered:
        return _run!.filteredResults
            .where((r) => r.isAccepted)
            .map((r) => latlong.LatLng(r.smoothedLat ?? r.raw.lat, r.smoothedLng ?? r.raw.lng))
            .toList();
      case MapLayer.matched:
        if (_run!.matchedResults != null) {
          return _run!.matchedResults!
              .where((r) => r.isAccepted)
              .map((r) => latlong.LatLng(r.smoothedLat ?? r.raw.lat, r.smoothedLng ?? r.raw.lng))
              .toList();
        }
        return [];
    }
  }

  double _calculateMatchedDistance() {
    if (_run?.matchedResults == null || _run!.matchedResults!.isEmpty) return 0.0;
    double dist = 0.0;
    final distance = const latlong.Distance();
    final points = _run!.matchedResults!.where((r) => r.isAccepted).toList();
    for (int i = 0; i < points.length - 1; i++) {
      dist += distance.distance(
        latlong.LatLng(points[i].smoothedLat ?? points[i].raw.lat, points[i].smoothedLng ?? points[i].raw.lng),
        latlong.LatLng(points[i+1].smoothedLat ?? points[i+1].raw.lat, points[i+1].smoothedLng ?? points[i+1].raw.lng),
      );
    }
    return dist;
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.tr('route_analysis', locale)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _run == null
            ? Center(child: Text(L10n.tr('run_not_found', locale)))
            : Column(
                children: [
                  if (_run!.matchedResults == null)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.s12),
                        color: Colors.orange.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.sync, color: Colors.orange),
                            const SizedBox(width: AppTheme.s12),
                            Expanded(
                              child: Text(
                                L10n.tr('route_matching_processing', locale),
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Layer Toggle
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.s16),
                    child: SegmentedButton<MapLayer>(
                      segments: [
                        ButtonSegment(value: MapLayer.raw, label: Text(L10n.tr('map_layer_raw', locale))),
                        ButtonSegment(value: MapLayer.filtered, label: Text(L10n.tr('map_layer_filtered', locale))),
                        ButtonSegment(value: MapLayer.matched, label: Text(L10n.tr('map_layer_matched', locale))),
                      ],
                      selected: {_selectedLayer},
                      onSelectionChanged: (Set<MapLayer> newSelection) {
                        setState(() {
                          _selectedLayer = newSelection.first;
                        });
                      },
                    ),
                  ),

                  Expanded(
                    flex: 2,
                    child: MwendoMap(
                      points: _getPointsForLayer(),
                      mode: MapMode.replay,
                      locationEnabled: false,
                      isRecording: false,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _report == null
                        ? const SizedBox()
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(L10n.tr('session_quality_report', locale), style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              _StatRow(L10n.tr('quality_grade', locale), _report!.grade.name.toUpperCase()),
                              _StatRow(L10n.tr('percent_ideal', locale), '${_report!.percentIdeal.toStringAsFixed(1)}%'),
                              _StatRow(L10n.tr('rejection_rate', locale), '${_report!.rejectionRatePct.toStringAsFixed(1)}%'),
                              _StatRow(L10n.tr('median_accuracy', locale), '${_report!.medianAccuracyM.toStringAsFixed(1)}m'),
                              _StatRow(L10n.tr('p95_accuracy', locale), '${_report!.p95AccuracyM.toStringAsFixed(1)}m'),
                              _StatRow(L10n.tr('signal_gaps', locale), '${_report!.signalGapCount}'),
                              _StatRow(L10n.tr('spikes_per_km', locale), '${_report!.jumpsPerKm}'),
                              _StatRow(L10n.tr('stationary_clusters', locale), '${_report!.stationaryClusterCount}'),
                              _StatRow(L10n.tr('filtered_distance', locale), '${(_report!.filteredDistanceM / 1000).toStringAsFixed(2)}km'),
                              _StatRow(L10n.tr('raw_distance', locale), '${(_report!.rawDistanceM / 1000).toStringAsFixed(2)}km'),
                              if (_run!.matchedResults != null && _run!.matchedResults!.isNotEmpty) ...[
                                const Divider(height: 32),
                                _StatRow(L10n.tr('map_match_status', locale), L10n.tr('map_match_success', locale)),
                                _StatRow(L10n.tr('matched_distance', locale), '${(_calculateMatchedDistance() / 1000).toStringAsFixed(2)}km'),
                              ] else if (_run!.rawFixes.isNotEmpty) ...[
                                const Divider(height: 32),
                                _StatRow(L10n.tr('map_match_status', locale), L10n.tr('map_match_pending', locale)),
                              ]
                            ],
                          ),
                  ),
                ],
              ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: '$label: $value',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(color: AppTheme.brand)),
          ],
        ),
      ),
    );
  }
}
