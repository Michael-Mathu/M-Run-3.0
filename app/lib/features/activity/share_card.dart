import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A route position in degrees. A plain record, so this file depends on no
/// map package (the app uses two with different `LatLng` classes).
typedef RoutePoint = ({double lat, double lng});

/// What goes on a shareable run image.
class ShareCardData {
  /// Activity name, e.g. "Run".
  final String title;
  final String dateLabel;

  /// "5.21" and "km", drawn large.
  final String distanceValue;
  final String distanceUnit;

  /// Up to three (label, value) pairs under the distance.
  final List<({String label, String value})> stats;

  /// The route, split where the recording paused. May be empty.
  final List<List<RoutePoint>> segments;

  /// Small line at the bottom, e.g. "Tracked with Mwendo".
  final String footer;

  const ShareCardData({
    required this.title,
    required this.dateLabel,
    required this.distanceValue,
    required this.distanceUnit,
    required this.stats,
    required this.segments,
    required this.footer,
  });
}

/// Size of the image: 9:16, the shape of a WhatsApp Status or Instagram story.
const double shareCardWidth = 1080;
const double shareCardHeight = 1920;

/// Fits [segments] into [box], keeping the route's true shape (east-west
/// distances are scaled by the cosine of the latitude, so a route is not
/// stretched away from the equator). Returns one polyline per segment; empty
/// when there is nothing drawable.
List<List<ui.Offset>> projectRoute(List<List<RoutePoint>> segments, ui.Rect box) {
  var count = 0;
  var latSum = 0.0;
  for (final s in segments) {
    for (final p in s) {
      latSum += p.lat;
      count++;
    }
  }
  if (count < 2) return const [];
  final k = math.cos(latSum / count * math.pi / 180);

  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final s in segments) {
    for (final p in s) {
      final x = p.lng * k, y = -p.lat;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  final dx = maxX - minX, dy = maxY - minY;
  // A recording that never left the spot has no shape to draw.
  if (dx < 1e-7 && dy < 1e-7) return const [];
  final scale = math.min(box.width / math.max(dx, 1e-7), box.height / math.max(dy, 1e-7));
  final ox = box.left + (box.width - dx * scale) / 2;
  final oy = box.top + (box.height - dy * scale) / 2;

  // Thousands of fixes add nothing at this size; keep roughly 1,500.
  final step = math.max(1, (count / 1500).ceil());
  final out = <List<ui.Offset>>[];
  for (final s in segments) {
    if (s.isEmpty) continue;
    final line = <ui.Offset>[];
    for (var i = 0; i < s.length; i += step) {
      line.add(ui.Offset(
          ox + (s[i].lng * k - minX) * scale, oy + (-s[i].lat - minY) * scale));
    }
    final last = s.last;
    final end = ui.Offset(
        ox + (last.lng * k - minX) * scale, oy + (-last.lat - minY) * scale);
    if (line.last != end) line.add(end);
    out.add(line);
  }
  return out;
}

ui.Paragraph _text(
  String s, {
  required double size,
  required FontWeight weight,
  required ui.Color color,
  String family = 'Inter',
  double spacing = 0,
  ui.TextAlign align = ui.TextAlign.left,
  double width = shareCardWidth,
}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: align, maxLines: 1, ellipsis: '…'))
    ..pushStyle(ui.TextStyle(
      color: color,
      fontSize: size,
      fontFamily: family,
      fontWeight: weight,
      letterSpacing: spacing,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    ))
    ..addText(s);
  return b.build()..layout(ui.ParagraphConstraints(width: width));
}

/// Draws the card and returns it as PNG bytes.
///
/// Drawn straight onto a canvas (no widget, no map tiles), so it can be
/// produced off-screen in a moment, works offline and needs no map
/// attribution: the route is a white line on the brand colours, the way run
/// stories are usually shared.
Future<Uint8List> renderShareCard(ShareCardData d) async {
  const w = shareCardWidth, h = shareCardHeight;
  const white = ui.Color(0xFFFFFFFF);
  const soft = ui.Color(0xB3FFFFFF);
  const faint = ui.Color(0x80FFFFFF);
  const margin = 96.0;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, w, h));

  // Red-earth background with a dawn glow in the corner.
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        const ui.Offset(w, h),
        const [ui.Color(0xFFA34424), ui.Color(0xFF5A2413), ui.Color(0xFF1C0C06)],
        const [0, 0.55, 1],
      ),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()
      ..shader = ui.Gradient.radial(
        const ui.Offset(w * 0.85, h * 0.08),
        780,
        const [ui.Color(0x59D89A2E), ui.Color(0x00D89A2E)],
      ),
  );

  // Header: wordmark and date.
  canvas.drawParagraph(
    _text('MWENDO',
        size: 46, weight: FontWeight.w800, color: white, family: 'InterDisplay', spacing: 12),
    const ui.Offset(margin, 104),
  );
  canvas.drawParagraph(
    _text(d.dateLabel,
        size: 34,
        weight: FontWeight.w500,
        color: soft,
        align: ui.TextAlign.right,
        width: w - margin * 2),
    const ui.Offset(margin, 112),
  );

  // Route.
  const routeBox = ui.Rect.fromLTWH(130, 290, w - 260, 800);
  final lines = projectRoute(d.segments, routeBox);
  final hasRoute = lines.isNotEmpty;
  if (hasRoute) {
    final path = ui.Path();
    for (final line in lines) {
      path.moveTo(line.first.dx, line.first.dy);
      for (var i = 1; i < line.length; i++) {
        path.lineTo(line[i].dx, line[i].dy);
      }
    }
    ui.Paint stroke(double width, ui.Color c) => ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..color = c;
    canvas.drawPath(path, stroke(34, const ui.Color(0x26FFFFFF)));
    canvas.drawPath(path, stroke(12, white));
    final start = lines.first.first, end = lines.last.last;
    canvas.drawCircle(start, 22, ui.Paint()..color = white);
    canvas.drawCircle(start, 14, ui.Paint()..color = const ui.Color(0xFF34C759));
    canvas.drawCircle(end, 22, ui.Paint()..color = white);
    canvas.drawCircle(end, 14, ui.Paint()..color = const ui.Color(0xFFB14A2A));
  }

  // Without a route the numbers move up to the middle of the card.
  final top = hasRoute ? 1180.0 : 700.0;

  canvas.drawParagraph(
    _text(d.title.toUpperCase(), size: 40, weight: FontWeight.w600, color: soft, spacing: 6),
    ui.Offset(margin, top),
  );
  final value = _text(d.distanceValue,
      size: 236, weight: FontWeight.w800, color: white, family: 'InterDisplay', spacing: -6);
  canvas.drawParagraph(value, ui.Offset(margin - 8, top + 36));
  final unit = _text(d.distanceUnit, size: 68, weight: FontWeight.w600, color: soft);
  canvas.drawParagraph(
    unit,
    ui.Offset(
      margin + value.longestLine + 16,
      top + 36 + value.alphabeticBaseline - unit.alphabeticBaseline,
    ),
  );

  final stats = d.stats.take(3).toList();
  if (stats.isNotEmpty) {
    final colW = (w - margin * 2) / 3;
    for (var i = 0; i < stats.length; i++) {
      final x = margin + colW * i;
      canvas.drawParagraph(
        _text(stats[i].value,
            size: 74,
            weight: FontWeight.w700,
            color: white,
            family: 'InterDisplay',
            width: colW - 16),
        ui.Offset(x, top + 356),
      );
      canvas.drawParagraph(
        _text(stats[i].label, size: 32, weight: FontWeight.w500, color: faint, width: colW - 16),
        ui.Offset(x, top + 452),
      );
    }
  }

  canvas.drawParagraph(
    _text(d.footer,
        size: 30,
        weight: FontWeight.w500,
        color: faint,
        align: ui.TextAlign.center,
        width: w - margin * 2),
    const ui.Offset(margin, h - 110),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not encode the share image');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
