import 'package:flutter/material.dart';

String formatDuration(int ms) {
  final s = (ms / 1000).floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

String formatPace(double minPerKm) {
  if (minPerKm <= 0) return '--:--';
  final m = minPerKm.floor();
  final s = ((minPerKm - m) * 60).round();
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatDistance(double meters) {
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(2)} km';
  return '${km.toStringAsFixed(1)} km';
}

TextStyle tabular(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

String formatClock(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Zero-padded DD/MM/YYYY, e.g. "07/03/2026" not "7/3/2026". Previously
/// activity_detail_page.dart built this inline without padding, which reads
/// ambiguously (is "3/7" March 7th or July 3rd?) -- padding removes that
/// ambiguity regardless of locale.
String formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}
