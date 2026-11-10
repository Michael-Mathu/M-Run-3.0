import 'mwendo_gps_engine_platform_interface.dart';
export 'mwendo_gps_engine_platform_interface.dart';

import 'mwendo_gps_engine_method_channel.dart';

bool _registered = false;
void _register() {
  if (_registered) return;
  _registered = true;
  MwendoGpsEnginePlatform.instance = MethodChannelMwendoGpsEngine();
}

class MwendoGpsEngine {
  MwendoGpsEngine() {
    _register();
  }

  Stream<TrackPoint> startRecording({BatteryProfile profile = BatteryProfile.standard}) {
    return MwendoGpsEnginePlatform.instance.startRecording(profile: profile);
  }

  /// Pre-run GPS warm-up; see [MwendoGpsEnginePlatform.warmUp].
  Stream<TrackPoint> warmUp() => MwendoGpsEnginePlatform.instance.warmUp();

  /// Stops the pre-run warm-up.
  Future<void> coolDown() => MwendoGpsEnginePlatform.instance.coolDown();

  /// 'precise' | 'approximate' | 'none' | 'unknown'.
  Future<String> locationAccuracy() => MwendoGpsEnginePlatform.instance.locationAccuracy();

  Future<void> pause() {
    return MwendoGpsEnginePlatform.instance.pause();
  }

  Future<void> resume() {
    return MwendoGpsEnginePlatform.instance.resume();
  }

  Future<RecordingSummary> stop() {
    return MwendoGpsEnginePlatform.instance.stop();
  }

  Stream<EngineState> get state {
    return MwendoGpsEnginePlatform.instance.state;
  }

  Future<EnginePlatformMetadata> getPlatformMetadata() {
    return MwendoGpsEnginePlatform.instance.getPlatformMetadata();
  }
}
