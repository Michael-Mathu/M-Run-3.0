import 'dart:math';

class CoordinateUtil {
  static const double _r = 6371000.0; // Earth radius in meters

  static double haversineMetres(
      double lat1, double lon1, double lat2, double lon2) {
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return _r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRad(lon2 - lon1);
    final y = sin(dLon) * cos(_toRad(lat2));
    final x = cos(_toRad(lat1)) * sin(_toRad(lat2)) -
        sin(_toRad(lat1)) * cos(_toRad(lat2)) * cos(dLon);
    return (_toDeg(atan2(y, x)) + 360) % 360;
  }

  /// Convert WGS84 to local ENU (East, North) meters relative to origin.
  /// Uses a flat-earth approximation suitable for short distances (< 50km).
  /// Wraps the longitude delta to [-180, 180] deg first so a fix near the
  /// antimeridian (e.g. origin 179.9, fix -179.9) resolves to the true short
  /// distance instead of the ~40,000km distance a raw subtraction implies.
  static (double east, double north) toEnu(
      double originLat, double originLng, double lat, double lng) {
    final dLat = _toRad(lat - originLat);
    final dLng = _toRad(_wrapLngDeltaDeg(lng - originLng));
    final north = dLat * _r;
    final east = dLng * _r * cos(_toRad(originLat));
    return (east, north);
  }

  /// Convert local ENU (East, North) meters back to WGS84 relative to origin.
  /// Normalizes the result longitude back into [-180, 180] deg, since an
  /// origin near +-180 plus an eastward/westward offset can otherwise land
  /// just outside that range.
  static (double lat, double lng) fromEnu(
      double originLat, double originLng, double east, double north) {
    final dLat = north / _r;
    final lat = originLat + _toDeg(dLat);
    final dLng = east / (_r * cos(_toRad(originLat)));
    final lng = _wrapLngDeltaDeg(originLng + _toDeg(dLng));
    return (lat, lng);
  }

  /// Wraps a longitude (or longitude delta) in degrees into (-180, 180].
  static double _wrapLngDeltaDeg(double deg) {
    var d = deg;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  static double _toRad(double d) => d * pi / 180;
  static double _toDeg(double r) => r * 180 / pi;
}
