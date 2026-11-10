import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/features/beat/ghost_race_controller.dart';
import 'package:mwendo_app/features/beat/ghost_race_utils.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';
import 'package:mwendo_app/widgets/glass.dart';

// ---- Basemap -------------------------------------------------------------
// OpenStreetMap data served as *vector* tiles by OpenFreeMap: free, no API
// key, no usage quota. Vector tiles are a fraction of the size of raster OSM
// tiles (important on mobile data), stay sharp at every zoom, and render on
// the GPU so panning stays at 60/120 fps. (Hitting tile.openstreetmap.org
// directly from an app breaches the OSM tile usage policy.)
//
// "Liberty" is OpenFreeMap's take on the classic OpenStreetMap look: green
// parks, blue water, colour-coded road classes and street names. It is used
// in both light and dark mode so the map always reads as OpenStreetMap (the
// earlier Positron/Dark styles were so muted they looked like a blank map).

/// The OpenStreetMap basemap style.
const kOsmStyle = 'https://tiles.openfreemap.org/styles/liberty';

/// Kept for call sites that pick by brightness; both are the OSM style.
const kLightStyle = kOsmStyle;
const kDarkStyle = kOsmStyle;

/// Default map centre (Nairobi) used before the first GPS fix arrives.
const kDefaultCenter = latlong.LatLng(-1.2921, 36.8219);

const _kRouteWidth = 5.0;

/// '#RRGGBB' for MapLibre from a Flutter colour.
String _hex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

const _kGhostRouteColor = '#FFFF5A1F';
const _kGhostRouteWidth = 4.0;
const _kGhostRouteOpacity = 0.7;
const _kGhostMarkerColor = '#FFFF5A1F';

// Style-layer ids (our own GeoJSON source + layers, not annotations, so we
// control line-join/cap and can draw several disconnected segments).
const _kRouteSource = 'mwendo-route';
const _kRouteCasing = 'mwendo-route-casing';
const _kRouteLine = 'mwendo-route-line';
const _kHeadSource = 'mwendo-head';
const _kHeadLayer = 'mwendo-head-dot';
const _kStartEndSource = 'mwendo-ends';
const _kStartEndLayer = 'mwendo-ends-dot';

/// How the [MwendoMap] behaves.
enum MapMode { live, replay }

class MwendoMap extends StatefulWidget {
  /// Flat list of route points. Still used for the ghost overlay and as the
  /// route when [segments] is not given.
  final List<latlong.LatLng> points;

  /// The route split at pauses / signal gaps. Each inner list is drawn as its
  /// own line, so a pause is never rendered as a straight jump.
  final List<List<latlong.LatLng>>? segments;
  final MapMode mode;
  final double zoom;
  final bool locationEnabled;
  final bool isRecording;
  final GhostPace? ghost;
  final double userDistanceM;
  final GhostRaceState? raceState;

  /// Live mode: a counter that changes whenever the route changes. When given,
  /// [points]/[segments] may be live (mutated in place) lists and the map
  /// pushes the route only when the revision changes — no per-rebuild copies.
  final int? routeRevision;

  const MwendoMap({
    super.key,
    required this.points,
    this.segments,
    this.mode = MapMode.replay,
    this.zoom = 14,
    this.locationEnabled = false,
    this.isRecording = false,
    this.ghost,
    this.userDistanceM = 0,
    this.raceState,
    this.routeRevision,
  });

  @override
  State<MwendoMap> createState() => _MwendoMapState();
}

class _MwendoMapState extends State<MwendoMap> {
  MapLibreMapController? _ctrl;
  Line? _ghostLine;
  Symbol? _ghostMarker;

  bool _layersReady = false;
  bool _isSyncing = false;
  bool _syncPending = false;

  bool _autoFollow = true;
  bool _firstFixDone = false;
  bool _styleLoaded = false;
  bool _didFitReplay = false;

  bool get _isLive => widget.mode == MapMode.live;

  List<List<latlong.LatLng>> get _segments =>
      (widget.segments ?? [widget.points]).where((s) => s.isNotEmpty).toList();

  latlong.LatLng? get _lastPoint {
    final segs = _segments;
    return segs.isEmpty ? null : segs.last.last;
  }

  int get _pointCount => _segments.fold(0, (n, s) => n + s.length);

  /// Point count at the last route push (detects a new run starting).
  int _syncedCount = 0;

  /// Whether this run's camera has already zoomed in to street level.
  bool _zoomedForRun = false;

  @override
  void didUpdateWidget(covariant MwendoMap old) {
    super.didUpdateWidget(old);
    final bool changed;
    if (widget.routeRevision != null) {
      changed = widget.routeRevision != old.routeRevision;
    } else {
      final oldCount = (old.segments ?? [old.points]).fold<int>(0, (n, s) => n + s.length);
      changed = _pointCount != oldCount ||
          (widget.segments?.length ?? 1) != (old.segments?.length ?? 1);
    }
    if (changed) {
      if (_pointCount < _syncedCount) {
        // New run started — reset camera behaviour.
        _autoFollow = true;
        _firstFixDone = false;
        _didFitReplay = false;
      }
      _syncRoute();
    }
    if (widget.isRecording != old.isRecording) {
      // A run starting always begins by following the runner.
      setState(() {
        if (widget.isRecording) _autoFollow = true;
        if (!widget.isRecording) _zoomedForRun = false;
      });
    }
    if (widget.ghost != old.ghost ||
        widget.userDistanceM != old.userDistanceM ||
        widget.raceState != old.raceState) {
      _syncGhostOverlay();
    }
  }

  // ---- GeoJSON -------------------------------------------------------------

  static List<List<double>> _coords(List<latlong.LatLng> pts) =>
      [for (final p in pts) [p.longitude, p.latitude]];

  /// Above this many points the drawn line is thinned (display only — the
  /// recorded track keeps every point). Keeps the per-fix GeoJSON push small
  /// on long runs; at running zooms the difference is invisible.
  static const _kMaxDrawnPoints = 3000;

  static List<latlong.LatLng> _thin(List<latlong.LatLng> s, int stride, {int keepTail = 0}) {
    if (stride <= 1 || s.length <= 2) return s;
    final tailStart = (s.length - keepTail).clamp(0, s.length);
    return [
      for (var i = 0; i < tailStart; i += stride) s[i],
      for (var i = tailStart; i < s.length; i++) s[i],
      if (tailStart == s.length && (s.length - 1) % stride != 0) s.last,
    ];
  }

  Map<String, dynamic> _routeGeoJson() {
    var lines = _segments.where((s) => s.length >= 2).toList();
    final total = lines.fold<int>(0, (n, s) => n + s.length);
    if (total > _kMaxDrawnPoints) {
      final stride = (total / _kMaxDrawnPoints).ceil();
      lines = [
        for (var i = 0; i < lines.length; i++)
          _thin(lines[i], stride, keepTail: i == lines.length - 1 ? 120 : 0),
      ];
    }
    return {
      'type': 'FeatureCollection',
      'features': [
        if (lines.isNotEmpty)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'MultiLineString',
              'coordinates': [for (final s in lines) _coords(s)],
            },
          },
      ],
    };
  }

  Map<String, dynamic> _pointGeoJson(List<(latlong.LatLng, String)> pts) => {
        'type': 'FeatureCollection',
        'features': [
          for (final (p, kind) in pts)
            {
              'type': 'Feature',
              'properties': {'kind': kind},
              'geometry': {
                'type': 'Point',
                'coordinates': [p.longitude, p.latitude],
              },
            },
        ],
      };

  Map<String, dynamic> _headGeoJson() {
    final last = _lastPoint;
    return _pointGeoJson(
        _isLive && widget.isRecording && last != null ? [(last, 'head')] : []);
  }

  Map<String, dynamic> _endsGeoJson() {
    final segs = _segments;
    if (_isLive || segs.isEmpty) return _pointGeoJson([]);
    return _pointGeoJson([(segs.first.first, 'start'), (segs.last.last, 'end')]);
  }

  Future<void> _addLayers() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    // The route uses the app's single brand tint (was a separate hard-coded red).
    final routeColor = _hex(Theme.of(context).colorScheme.primary);
    try {
      await ctrl.addGeoJsonSource(_kRouteSource, _routeGeoJson());
      // Casing under the line: keeps the route legible over busy streets.
      await ctrl.addLineLayer(
        _kRouteSource,
        _kRouteCasing,
        LineLayerProperties(
          // The OSM basemap is light in both themes, so a white casing.
          lineColor: '#FFFFFF',
          lineWidth: _kRouteWidth + 3,
          lineOpacity: 0.9,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        enableInteraction: false,
      );
      // Round joins/caps: the old annotation line used miter joins, which
      // render GPS zig-zags as sharp spikes.
      await ctrl.addLineLayer(
        _kRouteSource,
        _kRouteLine,
        LineLayerProperties(
          lineColor: routeColor,
          lineWidth: _kRouteWidth,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        enableInteraction: false,
      );
      await ctrl.addGeoJsonSource(_kStartEndSource, _endsGeoJson());
      await ctrl.addCircleLayer(
        _kStartEndSource,
        _kStartEndLayer,
        CircleLayerProperties(
          circleRadius: 6,
          circleColor: [
            'match',
            ['get', 'kind'],
            'start',
            '#34C759',
            routeColor,
          ],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.5,
        ),
        enableInteraction: false,
      );
      // Live position marker drawn from the *filtered* track, so the dot always
      // sits on the end of the line (the native puck shows the raw, jittery OS
      // location and visibly wanders off the route — the "ghosting" effect).
      await ctrl.addGeoJsonSource(_kHeadSource, _headGeoJson());
      await ctrl.addCircleLayer(
        _kHeadSource,
        _kHeadLayer,
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#0A84FF',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
        enableInteraction: false,
      );
      _layersReady = true;
    } catch (e) {
      debugPrint('MwendoMap: failed to add route layers: $e');
    }
  }

  void _syncRoute() {
    if (_ctrl == null || !_layersReady) return;
    if (_isSyncing) {
      _syncPending = true;
      return;
    }
    _isSyncing = true;
    _pushRoute().whenComplete(() {
      _isSyncing = false;
      if (!mounted) return;
      if (_syncPending) {
        _syncPending = false;
        _syncRoute();
      }
    });
  }

  Future<void> _pushRoute() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _syncedCount = _pointCount;
    try {
      await ctrl.setGeoJsonSource(_kRouteSource, _routeGeoJson());
      await ctrl.setGeoJsonSource(_kHeadSource, _headGeoJson());
      await ctrl.setGeoJsonSource(_kStartEndSource, _endsGeoJson());
    } catch (e) {
      debugPrint('MwendoMap: route update failed: $e');
      return;
    }
    if (!mounted) return;

    if (_isLive) {
      final last = _lastPoint;
      if (last != null && _autoFollow && widget.isRecording) {
        // First follow of a run zooms in to street level; after that only
        // pan, so a zoom the runner chose is kept.
        final zoomIn = !_zoomedForRun;
        _zoomedForRun = true;
        await ctrl.animateCamera(
          zoomIn ? CameraUpdate.newLatLngZoom(_toMl(last), 16) : CameraUpdate.newLatLng(_toMl(last)),
          duration: const Duration(milliseconds: 700),
        );
      }
    } else if (!_didFitReplay) {
      _didFitReplay = true;
      await _fitToRoute();
    }
  }

  /// Frames the whole route (replay). The old replay centred on the last point
  /// at a fixed zoom, so most of a long run was off-screen.
  Future<void> _fitToRoute() async {
    final ctrl = _ctrl;
    final all = [for (final s in _segments) ...s];
    if (ctrl == null || all.isEmpty) return;
    var minLat = all.first.latitude, maxLat = minLat;
    var minLng = all.first.longitude, maxLng = minLng;
    for (final p in all) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // Avoid a zero-size box (single point / straight N-S line).
    const pad = 0.0005;
    if (maxLat - minLat < pad) {
      minLat -= pad;
      maxLat += pad;
    }
    if (maxLng - minLng < pad) {
      minLng -= pad;
      maxLng += pad;
    }
    try {
      await ctrl.moveCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 40,
        top: 40,
        right: 40,
        bottom: 40,
      ));
    } catch (_) {}
  }

  LatLng _toMl(latlong.LatLng ll) => LatLng(ll.latitude, ll.longitude);

  List<LatLng> _toMlList(List<latlong.LatLng> points) =>
      points.map(_toMl).toList();

  // ---- Ghost overlay (annotations, unchanged behaviour) --------------------

  Future<void> _syncGhostOverlay() async {
    final ctrl = _ctrl;
    if (ctrl == null || widget.ghost == null || !_isLive) return;

    final ghost = widget.ghost!;
    final routePoints = widget.points;
    if (routePoints.length < 2) return;

    _ghostLine ??= await ctrl.addLine(LineOptions(
      geometry: _toMlList(routePoints),
      lineColor: _kGhostRouteColor,
      lineWidth: _kGhostRouteWidth,
      lineOpacity: _kGhostRouteOpacity,
      linePattern: 'dash',
    ));

    final ghostPos = computeGhostPosition(
      ghost,
      widget.userDistanceM,
      routePoints,
    );

    if (ghostPos != null) {
      if (_ghostMarker == null) {
        _ghostMarker = await ctrl.addSymbol(SymbolOptions(
          geometry: _toMl(ghostPos),
          iconImage: 'marker',
          iconSize: 1.2,
          iconColor: _kGhostMarkerColor,
          iconHaloColor: '#FFFFFF',
          iconHaloWidth: 2,
          iconHaloBlur: 4,
        ));
      } else {
        final pulse =
            1.0 + 0.3 * math.sin(DateTime.now().millisecondsSinceEpoch / 300);
        await ctrl.updateSymbol(
            _ghostMarker!,
            SymbolOptions(
              geometry: _toMl(ghostPos),
              iconSize: 1.2 * pulse,
            ));
      }
    }
  }

  // ---- Location puck / follow ----------------------------------------------

  /// Native OS location puck: shown before a run starts (so you can see where
  /// you are), hidden while recording, when the filtered head dot takes over.
  bool get _showNativePuck =>
      _isLive && widget.locationEnabled && _styleLoaded && !widget.isRecording;

  MyLocationTrackingMode get _trackingMode {
    if (!_showNativePuck || !_autoFollow) return MyLocationTrackingMode.none;
    return MyLocationTrackingMode.tracking;
  }

  void _toggleAutoFollow() {
    if (_autoFollow) {
      setState(() => _autoFollow = false);
    } else {
      _recenter();
    }
  }

  void _recenter() {
    setState(() => _autoFollow = true);
    final ctrl = _ctrl;
    final last = _lastPoint;
    if (ctrl != null && last != null) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(_toMl(last), 16));
    }
  }

  @override
  void dispose() {
    if (_ghostLine != null) _ctrl?.removeLine(_ghostLine!);
    if (_ghostMarker != null) _ctrl?.removeSymbol(_ghostMarker!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLive && _pointCount < 2) {
      return _EmptyRoutePlaceholder();
    }

    final last = _lastPoint;
    final initialTarget = _toMl(last ?? kDefaultCenter);

    final map = MapLibreMap(
      key: const ValueKey('mwendo-map-osm'),
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: _isLive ? (last != null ? 16 : 12) : widget.zoom,
      ),
      styleString: kOsmStyle,
      // OSM attribution is a licence requirement — keep it, but out of the way
      // of our own controls on the right.
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      compassEnabled: false,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      myLocationEnabled: _showNativePuck,
      myLocationTrackingMode: _trackingMode,
      onMapCreated: (c) {
        _ctrl = c;
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_styleLoaded) {
            setState(() => _styleLoaded = true);
          }
        });
      },
      onStyleLoadedCallback: () async {
        _styleLoaded = true;
        // Liberty draws 3D-extruded buildings from zoom 14; runs are shown at
        // zoom 16, so that's a constant GPU cost (and it hides the route).
        // Keep the flat building footprints, drop the extrusion layer.
        try {
          await _ctrl?.removeLayer('building-3d');
        } catch (_) {}
        _layersReady = false;
        _ghostLine = null;
        _ghostMarker = null;
        _didFitReplay = false;
        await _addLayers();
        _syncRoute();
        if (mounted) setState(() {});
      },
      onCameraTrackingDismissed: () {
        // While recording the native tracking mode is off, so this only fires
        // when *we* switch it off at the start of a run — not a user pan.
        // Treating that as "stop following" left the camera behind.
        if (mounted && !widget.isRecording) setState(() => _autoFollow = false);
      },
      onMapClick: _isLive
          ? null
          : (_, _) {
              // Tap a replay map to re-frame the whole route.
              _fitToRoute();
            },
      onUserLocationUpdated: _isLive
          ? (userLocation) {
              if (_ctrl != null && !_firstFixDone) {
                _firstFixDone = true;
                _ctrl!.animateCamera(
                  CameraUpdate.newLatLngZoom(userLocation.position, 16),
                );
              }
            }
          : null,
    );

    return Stack(
      children: [
        map,
        if (!_styleLoaded)
          Center(
            child: CircularProgressIndicator.adaptive(
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black45),
            ),
          ),
        if (_isLive)
          Positioned(
            right: AppTheme.s16,
            bottom: AppTheme.s16,
            child: _AutoFollowToggleButton(
              isFollowing: _autoFollow,
              onTap: _toggleAutoFollow,
            ),
          ),
      ],
    );
  }
}

class _AutoFollowToggleButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _AutoFollowToggleButton({
    required this.isFollowing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: isFollowing ? Icons.navigation_rounded : Icons.navigation_outlined,
      onPressed: onTap,
      semanticLabel: isFollowing ? 'Stop following my location' : 'Follow my location',
      color: const Color(0xFF0A84FF),
    );
  }
}

class _EmptyRoutePlaceholder extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 36, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppTheme.s8),
            Text(ref.tr('no_route_recorded'),
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}
