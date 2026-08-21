import Flutter
import UIKit
import CoreLocation

public class MwendoGpsEnginePlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, FlutterStreamHandler {
    var locationManager: CLLocationManager?
    var eventSink: FlutterEventSink?
    var activityId: String = UUID().uuidString
    var startTime: Int = 0

    // Set while startRecording() is waiting on an authorization decision the
    // user hasn't made yet (status == .notDetermined). Resolved once
    // locationManagerDidChangeAuthorization/didChangeAuthorization fires.
    // Previously startRecording() never checked authorization at all and
    // always returned success immediately -- silently recording nothing if
    // permission was denied, and risking a crash on any device where
    // Info.plist's usage-description keys are missing (see
    // docs/BUILD_PLAN.md SEC-14).
    private var pendingStartResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "mwendo_gps_engine", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "mwendo_gps_engine/events", binaryMessenger: registrar.messenger())
        let instance = MwendoGpsEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecording":
            startRecording(result: result)
        case "pause":
            pause(result: result)
        case "resume":
            resume(result: result)
        case "stop":
            stop(result: result)
        case "getPlatformMetadata":
            getPlatformMetadata(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(with arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(with arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func currentAuthorizationStatus(_ manager: CLLocationManager) -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    private func startRecording(result: @escaping FlutterResult) {
        activityId = UUID().uuidString
        startTime = Int(Date().timeIntervalSince1970 * 1000)

        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
        }
        guard let manager = locationManager else {
            result(FlutterError(code: "LOCATION_MANAGER_UNAVAILABLE", message: "Could not create a CLLocationManager", details: nil))
            return
        }
        manager.allowsBackgroundLocationUpdates = true
        // Keep recording while the app is backgrounded; do not let Core Location
        // auto-pause the stream when it detects little movement.
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5

        switch currentAuthorizationStatus(manager) {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            result(["activity_id": activityId])
        case .notDetermined:
            // Async: the actual decision comes back through
            // locationManagerDidChangeAuthorization/didChangeAuthorization.
            // If a previous start is still pending (e.g. a rapid double-tap),
            // resolve it as cancelled first so the channel never gets two
            // replies for one call.
            if let previous = pendingStartResult {
                previous(FlutterError(code: "SUPERSEDED", message: "A newer startRecording call replaced this one", details: nil))
            }
            pendingStartResult = result
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            result(FlutterError(code: "PERMISSION_DENIED", message: "Location permission was denied. Enable it in Settings to record a run.", details: nil))
        @unknown default:
            result(FlutterError(code: "PERMISSION_UNKNOWN", message: "Unknown location authorization status.", details: nil))
        }
    }

    private func pause(result: FlutterResult) {
        locationManager?.stopUpdatingLocation()
        result(nil)
    }

    private func resume(result: FlutterResult) {
        locationManager?.startUpdatingLocation()
        result(nil)
    }

    private func stop(result: FlutterResult) {
        locationManager?.stopUpdatingLocation()
        let duration = Int(Date().timeIntervalSince1970 * 1000) - startTime
        result([
            "activity_id": activityId,
            "duration_ms": duration,
        ])
    }

    private func getPlatformMetadata(result: FlutterResult) {
        let osVersion = UIDevice.current.systemVersion
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let hardwareModel = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        result([
            "osVersion": "iOS " + osVersion,
            "hardwareModel": hardwareModel,
            "appVersion": appVersion
        ])
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            processLocation(location)
        }
    }

    // iOS 14+ authorization-change callback.
    @available(iOS 14.0, *)
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange(manager.authorizationStatus)
    }

    // Pre-iOS 14 authorization-change callback (the only one that fires on
    // iOS 13, which this plugin's podspec still targets).
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if #available(iOS 14.0, *) {
            return // handled by locationManagerDidChangeAuthorization above
        }
        handleAuthorizationChange(status)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard let pending = pendingStartResult else { return }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            pendingStartResult = nil
            locationManager?.startUpdatingLocation()
            pending(["activity_id": activityId])
        case .denied, .restricted:
            pendingStartResult = nil
            pending(FlutterError(code: "PERMISSION_DENIED", message: "Location permission was denied. Enable it in Settings to record a run.", details: nil))
        case .notDetermined:
            break // still waiting on the user's decision
        @unknown default:
            pendingStartResult = nil
            pending(FlutterError(code: "PERMISSION_UNKNOWN", message: "Unknown location authorization status.", details: nil))
        }
    }

    // Previously unimplemented -- CoreLocation errors (GPS signal lost, etc.)
    // were silently swallowed instead of surfaced to Dart.
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        eventSink?(FlutterError(code: "LOCATION_ERROR", message: error.localizedDescription, details: nil))
    }

    private func processLocation(_ location: CLLocation) {
        let speed = max(0.0, location.speed)

        var isMocked = false
        if #available(iOS 15.0, *) {
            isMocked = location.sourceInformation?.isSimulatedBySoftware == true || location.sourceInformation?.isProducedByAccessory == true
        }

        var bearing: Double? = nil
        var bearingAccuracy: Double? = nil
        if location.course >= 0 {
            bearing = location.course
            if #available(iOS 13.4, *) {
                bearingAccuracy = location.courseAccuracy >= 0 ? location.courseAccuracy : nil
            }
        }

        eventSink?([
            "lat": location.coordinate.latitude,
            "lng": location.coordinate.longitude,
            "elevation": location.altitude,
            "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000),
            "speed": speed,
            "accuracy": location.horizontalAccuracy,
            "verticalAccuracy": location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            "hdop": nil,
            "satelliteCount": nil, // CoreLocation doesn't expose satellite count
            "provider": "gps",
            "isMocked": isMocked,
            "fixType": "unknown",
            "bearing": bearing,
            "bearingAccuracy": bearingAccuracy,
        ])
    }
}
