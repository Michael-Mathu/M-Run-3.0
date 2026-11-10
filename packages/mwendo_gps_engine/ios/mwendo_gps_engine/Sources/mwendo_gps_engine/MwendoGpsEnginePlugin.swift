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

    // Pre-run GPS warm-up: while the Run screen is open, Core Location runs at
    // best accuracy so satellites are locked before Start is tapped. Fixes are
    // tagged "preview" until recording begins.
    private var isRecording = false
    private var isPreviewing = false

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
        case "warmUp":
            warmUp(result: result)
        case "coolDown":
            coolDown(result: result)
        case "locationAccuracy":
            locationAccuracy(result: result)
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
            isPreviewing = false
            isRecording = true
            manager.startUpdatingLocation()
            result(["activity_id": activityId])
            seedFromLastLocation(manager)
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

    private func warmUp(result: FlutterResult) {
        if isRecording {
            result(true)
            return
        }
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
        }
        guard let manager = locationManager else {
            result(false)
            return
        }
        let status = currentAuthorizationStatus(manager)
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            result(false)
            return
        }
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = kCLDistanceFilterNone
        isPreviewing = true
        // Instant: Core Location's cached position, if reasonably recent.
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < 120 {
            processLocation(cached)
        }
        manager.startUpdatingLocation()
        result(true)
    }

    /// "precise", "approximate" (iOS 14 Precise Location off) or "none".
    private func locationAccuracy(result: FlutterResult) {
        let manager = locationManager ?? CLLocationManager()
        let status = currentAuthorizationStatus(manager)
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            result("none")
            return
        }
        if #available(iOS 14.0, *) {
            result(manager.accuracyAuthorization == .fullAccuracy ? "precise" : "approximate")
        } else {
            result("precise")
        }
    }

    private func coolDown(result: FlutterResult) {
        if !isRecording && isPreviewing {
            isPreviewing = false
            locationManager?.stopUpdatingLocation()
        }
        result(nil)
    }

    /// Recording just started: emit the freshest known fix as the first point
    /// (the Dart pipeline still gates it on accuracy) so the run has a position
    /// immediately instead of waiting for the next GNSS delivery.
    private func seedFromLastLocation(_ manager: CLLocationManager) {
        guard let loc = manager.location else { return }
        let age = -loc.timestamp.timeIntervalSinceNow
        if age >= 0 && age <= 10 && loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy <= 30 {
            processLocation(loc)
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
        isRecording = false
        isPreviewing = false
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
            isPreviewing = false
            isRecording = true
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
        // CoreLocation reports a negative speed when it's invalid; pass -1
        // ("unknown") through instead of clamping to 0 (= "standing still").
        let speed = location.speed >= 0 ? location.speed : -1.0

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
            "preview": isPreviewing && !isRecording,
        ])
    }
}
