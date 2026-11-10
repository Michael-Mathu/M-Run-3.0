import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mwendo_app/core/theme/app_theme.dart';

/// Tiny drawing of a run's path for list rows (Apple Fitness style). Pure
/// vector, no map tiles — costs nothing on mobile data and scrolls smoothly.
/// Falls back to [fallbackIcon] when there is no route.
class RouteThumbnail extends StatelessWidget {
  final List<List<LatLng>> segments;
  final double size;
  final Color? color;
  final IconData fallbackIcon;

  const RouteThumbnail({
    super.key,
    required this.segments,
    this.size = 48,
    this.color,
    this.fallbackIcon = Icons.directions_run_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = color ?? cs.primary;
    final hasRoute = segments.any((s) => s.length >= 2);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.r12),
      ),
      child: hasRoute
          ? Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: RepaintBoundary(
                child: CustomPaint(painter: _RoutePainter(segments, tint)),
              ),
            )
          : Icon(fallbackIcon, color: tint, size: size * 0.5),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<List<LatLng>> segments;
  final Color color;
  _RoutePainter(this.segments, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final s in segments) {
      for (final p in s) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
    }
    if (!minLat.isFinite) return;
    // Equirectangular projection corrected for latitude so shapes aren't
    // stretched; fit into the box keeping aspect ratio.
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max((maxLng - minLng) * kx, 1e-9);
    final h = math.max(maxLat - minLat, 1e-9);
    final scale = math.min(size.width / w, size.height / h);
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;
    Offset project(LatLng p) => Offset(
          dx + (p.longitude - minLng) * kx * scale,
          dy + (maxLat - p.latitude) * scale,
        );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in segments) {
      if (s.length < 2) continue;
      // Thin out long routes — a 48 px drawing doesn't need 3 000 points.
      final step = math.max(1, s.length ~/ 150);
      final path = Path()..moveTo(project(s.first).dx, project(s.first).dy);
      for (var i = step; i < s.length; i += step) {
        final o = project(s[i]);
        path.lineTo(o.dx, o.dy);
      }
      final last = project(s.last);
      path.lineTo(last.dx, last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.segments != segments || old.color != color;
}
