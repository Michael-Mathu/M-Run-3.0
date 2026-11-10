import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'mwendo_gps_engine_method_channel.dart';
import 'src/normalized_fix.dart';

export 'src/normalized_fix.dart';

enum BatteryProfile { standard, powerSaver, ultraSaver }
enum EngineState { idle, recording, paused, recovering }

class TrackPoint {
  final NormalizedFix raw;
  final int? heartRate;
  final int? cadence;
  final String state;

  TrackPoint({
    required this.raw,
    this.heartRate,
    this.cadence,
    required this.state,
  });
  
  // Forwarders for backward compatibility
  double get lat => raw.lat;
  double get lng => raw.lng;
  double get elevation => raw.elevation;
  DateTime get timestamp => raw.timestamp;
  double get speedMps => raw.speedMps;
  int get accuracy => raw.accuracyM.toInt();
  double? get hdop => raw.hdop;
  int? get satelliteCount => raw.satelliteCount;
  String get provider => raw.provider;
  bool get isMocked => raw.isMocked;
  String get fixType => raw.fixType;
}

class RecordingSummary {
  final String activityId;
  final double distanceM;
  final int durationMs;
  final int movingTimeMs;

  RecordingSummary({
    required this.activityId,
    required this.distanceM,
    required this.durationMs,
    required this.movingTimeMs,
  });
}

class EnginePlatformMetadata {
  final String osVersion;
  final String hardwareModel;
  final String appVersion;

  EnginePlatformMetadata({
    required this.osVersion,
    required this.hardwareModel,
    required this.appVersion,
  });
}

abstract class MwendoGpsEnginePlatform extends PlatformInterface {
  MwendoGpsEnginePlatform() : super(token: _token);
  static final Object _token = Object();

  static MwendoGpsEnginePlatform? _instance;

  static MwendoGpsEnginePlatform get instance {
    _instance ??= MethodChannelMwendoGpsEngine();
    return _instance!;
  }

  static set instance(MwendoGpsEnginePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<TrackPoint> startRecording({BatteryProfile profile});

  /// Starts a pre-run GPS warm-up so satellites are locked before recording
  /// starts, and returns the stream of *preview* fixes (never recorded). The
  /// first event is usually the system's cached position, delivered
  /// immediately. Recording automatically ends the warm-up and uses the
  /// freshest warm fix as its first point.
  Stream<TrackPoint> warmUp() => const Stream.empty();

  /// Stops the warm-up (no effect while recording).
  Future<void> coolDown() async {}

  /// Location permission level: 'precise', 'approximate' (Android 12+ /
  /// iOS 14+ "Approximate"/"Precise: Off" — too coarse to track a run) or
  /// 'none'. 'unknown' when the platform can't tell.
  Future<String> locationAccuracy() async => 'unknown';
  Future<void> pause();
  Future<void> resume();
  Future<RecordingSummary> stop();
  Stream<EngineState> get state;
  
  Future<EnginePlatformMetadata> getPlatformMetadata() async {
    throw UnimplementedError('getPlatformMetadata() has not been implemented.');
  }
}