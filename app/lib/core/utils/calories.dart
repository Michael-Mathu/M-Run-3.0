import 'package:gps_pipeline/gps_pipeline.dart';

/// Estimated energy for an activity, in kilocalories.
///
/// The old estimate was a flat 11 kcal per minute for everyone and every
/// activity. This one scales with body weight and with what was actually
/// done:
///
/// * Run / walk / hike: cost per kilogram per kilometre (the standard
///   "gross" figures: about 1.03 running, 0.73 walking), plus the ACSM
///   vertical term for climbing.
/// * Cycle: MET by average moving speed (Compendium of Physical Activities).
/// * Indoor / poor signal: distance is unreliable, so a moderate MET by time.
/// * Drive: none.
///
/// It is still an estimate (no heart rate), good to roughly ±20%.
int estimateCalories({
  required ActivityProfile profile,
  required double weightKg,
  required double distanceM,
  required double elevationGainM,
  required int movingMs,
  required int elapsedMs,
}) {
  if (weightKg <= 0) return 0;
  final km = distanceM <= 0 ? 0.0 : distanceM / 1000;
  final climb = elevationGainM <= 0 ? 0.0 : elevationGainM;
  double kcal;
  switch (profile) {
    case ActivityProfile.run:
      kcal = weightKg * (1.03 * km + 0.0045 * climb);
    case ActivityProfile.walk:
      kcal = weightKg * (0.73 * km + 0.009 * climb);
    case ActivityProfile.hike:
      kcal = weightKg * (0.85 * km + 0.009 * climb);
    case ActivityProfile.cycle:
      final hours = movingMs / 3600000;
      if (hours <= 0) return 0;
      kcal = cyclingMet(km / hours) * weightKg * hours;
    case ActivityProfile.indoorPoor:
      kcal = 5.0 * weightKg * (elapsedMs / 3600000);
    case ActivityProfile.drive:
      kcal = 0;
  }
  return kcal.isFinite && kcal > 0 ? kcal.round() : 0;
}

/// MET for cycling at an average speed in km/h.
double cyclingMet(double kmh) {
  if (kmh < 16) return 4.0;
  if (kmh < 19) return 6.8;
  if (kmh < 22.5) return 8.0;
  if (kmh < 25.7) return 10.0;
  if (kmh < 32) return 12.0;
  return 15.8;
}
