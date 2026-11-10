class NormalizedFix {
  final double lat;
  final double lng;
  final double elevation;
  final DateTime timestamp;
  /// Device-reported (Doppler) speed in m/s; negative means "not reported".
  final double speedMps;
  final double accuracyM;
  final double? verticalAccuracyM;
  final double? hdop;
  final int? satelliteCount;
  final String provider;
  final bool isMocked;
  final String fixType;
  final double? bearingDeg;
  final double? bearingAccuracyDeg;
  
  const NormalizedFix({
    required this.lat,
    required this.lng,
    required this.elevation,
    required this.timestamp,
    required this.speedMps,
    required this.accuracyM,
    this.verticalAccuracyM,
    this.hdop,
    this.satelliteCount,
    required this.provider,
    required this.isMocked,
    required this.fixType,
    this.bearingDeg,
    this.bearingAccuracyDeg,
  });

  /// Missing or negative speed (Android `!hasSpeed()`, iOS invalid speed)
  /// becomes -1 = "unknown". It must not become 0, which means "stopped".
  static double _speed(Object? v) {
    final s = (v as num?)?.toDouble();
    return (s == null || s < 0) ? -1.0 : s;
  }

  factory NormalizedFix.fromMap(Map<dynamic, dynamic> map) {
    return NormalizedFix(
      lat: map['lat'] as double,
      lng: map['lng'] as double,
      elevation: map['elevation'] as double? ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int, isUtc: true),
      speedMps: _speed(map['speed']),
      accuracyM: map['accuracy'] as double? ?? 10.0,
      verticalAccuracyM: map['verticalAccuracy'] as double?,
      hdop: map['hdop'] as double?,
      satelliteCount: map['satelliteCount'] as int?,
      provider: map['provider'] as String? ?? 'unknown',
      isMocked: map['isMocked'] as bool? ?? false,
      fixType: map['fixType'] as String? ?? 'unknown',
      bearingDeg: map['bearing'] as double?,
      bearingAccuracyDeg: map['bearingAccuracy'] as double?,
    );
  }
}
