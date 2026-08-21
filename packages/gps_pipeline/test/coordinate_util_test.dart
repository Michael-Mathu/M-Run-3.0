import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('CoordinateUtil.haversineMetres', () {
    test('same point is zero distance', () {
      expect(CoordinateUtil.haversineMetres(1.0, 1.0, 1.0, 1.0), 0.0);
    });

    test('one degree of latitude at the equator is ~111.19km', () {
      final d = CoordinateUtil.haversineMetres(0, 0, 1, 0);
      expect(d, closeTo(111195, 50));
    });
  });

  group('CoordinateUtil.bearingDeg', () {
    test('due north is ~0 degrees', () {
      final b = CoordinateUtil.bearingDeg(0, 0, 1, 0);
      expect(b, closeTo(0, 0.5));
    });

    test('due east is ~90 degrees', () {
      final b = CoordinateUtil.bearingDeg(0, 0, 0, 1);
      expect(b, closeTo(90, 0.5));
    });

    test('due south is ~180 degrees', () {
      final b = CoordinateUtil.bearingDeg(1, 0, 0, 0);
      expect(b, closeTo(180, 0.5));
    });

    test('due west is ~270 degrees (wrapped positive, not negative)', () {
      final b = CoordinateUtil.bearingDeg(0, 1, 0, 0);
      expect(b, closeTo(270, 0.5));
      expect(b, greaterThanOrEqualTo(0));
    });
  });

  group('CoordinateUtil.toEnu / fromEnu', () {
    test('the origin maps to (0, 0)', () {
      final (east, north) = CoordinateUtil.toEnu(10.0, 20.0, 10.0, 20.0);
      expect(east, closeTo(0, 1e-9));
      expect(north, closeTo(0, 1e-9));
    });

    test('a small north offset produces ~zero east and the expected north distance', () {
      final (east, north) = CoordinateUtil.toEnu(0, 0, 0.001, 0);
      expect(east, closeTo(0, 1e-6));
      expect(north, closeTo(111.195, 0.5)); // 0.001 deg * ~111.195 m/deg
    });

    test('toEnu then fromEnu round-trips back to the original coordinate', () {
      const originLat = 37.5, originLng = -122.3;
      const lat = 37.512, lng = -122.289;
      final (east, north) = CoordinateUtil.toEnu(originLat, originLng, lat, lng);
      final (lat2, lng2) = CoordinateUtil.fromEnu(originLat, originLng, east, north);
      expect(lat2, closeTo(lat, 1e-9));
      expect(lng2, closeTo(lng, 1e-9));
    });

    test('regression (docs/BUILD_PLAN.md PF-5): antimeridian crossing resolves to the true short distance', () {
      // True distance from 179.9 to -179.9 longitude at the equator is
      // ~22.2km (crossing the antimeridian), not the ~40,000km a raw
      // subtraction of the two longitudes would imply.
      final (east, _) = CoordinateUtil.toEnu(0, 179.9, 0, -179.9);
      expect(east.abs(), closeTo(22239, 50));
    });

    test('fromEnu normalizes a result longitude that crosses the antimeridian back into [-180, 180]', () {
      // Origin near +180, offset east by ~22.2km -- the raw sum would land
      // just past +180 without wraparound.
      final (_, lng) = CoordinateUtil.fromEnu(0, 179.9, 22239, 0);
      expect(lng, closeTo(-179.9, 0.01));
    });
  });
}
