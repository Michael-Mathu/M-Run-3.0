package com.mwendo.mwendo_gps_engine

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.location.Location
import android.os.IBinder
import android.os.SystemClock
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class MwendoGpsEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    MwendoTrackingService.LocationListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var service: MwendoTrackingService? = null
    private var bound = false
    private var pendingStartResult: Result? = null
    private var pendingProfile: String = "standard"

    // ---- Pre-run GPS warm-up ------------------------------------------------
    // Satellite acquisition (time to first fix) is the slow part of starting a
    // run. While the Run screen is open we keep a high-accuracy request alive so
    // the GNSS chip is already locked when the user taps Start, show the
    // system's last known position instantly, and hand the freshest warm fix
    // to the recording as its first point.
    private var fused: FusedLocationProviderClient? = null
    private var previewCallback: LocationCallback? = null
    private var latestPreview: Location? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val svc = (binder as MwendoTrackingService.LocalBinder).getService()
            service = svc
            bound = true
            svc.setListener(this@MwendoGpsEnginePlugin)
            svc.start(pendingProfile)
            handOverFromWarmUp(svc)
            if (!svc.foregroundReady) {
                // Foreground service failed to start — surface the failure
                // instead of leaving Dart believing the run is recording (C2).
                pendingStartResult?.error(
                    "FOREGROUND_FAILED",
                    "Tracking service could not start in the foreground",
                    null,
                )
                pendingStartResult = null
                return
            }
            pendingStartResult?.success(mapOf("activity_id" to svc.activityId))
            pendingStartResult = null
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            bound = false
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "mwendo_gps_engine")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "mwendo_gps_engine/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startRecording" -> {
                pendingProfile = call.argument<String>("profile") ?: "standard"
                startService(result)
            }
            "warmUp" -> result.success(warmUp())
            "locationAccuracy" -> {
                // Android 12+ lets users grant only "Approximate" location
                // (~1-3 km): every fix would then be rejected as inaccurate
                // and a run would record nothing. Report it so the app can ask
                // for "Precise".
                val fine = ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
                val coarse = ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
                result.success(if (fine) "precise" else if (coarse) "approximate" else "none")
            }
            "coolDown" -> {
                stopWarmUp()
                result.success(null)
            }
            "pause" -> {
                service?.pause()
                result.success(null)
            }
            "resume" -> {
                service?.resume()
                result.success(null)
            }
            "stop" -> {
                val summary = service?.stop() ?: mapOf(
                    "activity_id" to "",
                    "distance_m" to 0.0,
                    "duration_ms" to 0,
                    "moving_time_ms" to 0,
                )
                stopService()
                result.success(summary)
            }
            "getPlatformMetadata" -> {
                val osVersion = android.os.Build.VERSION.RELEASE
                val hardwareModel = android.os.Build.MODEL
                var appVersion = "unknown"
                try {
                    val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                    appVersion = pInfo.versionName ?: "unknown"
                } catch (e: Exception) {
                    // Ignore
                }
                result.success(mapOf(
                    "osVersion" to "Android $osVersion",
                    "hardwareModel" to hardwareModel,
                    "appVersion" to appVersion
                ))
            }
            else -> result.notImplemented()
        }
    }

    private fun startService(result: Result) {
        // Capture and immediately null the pending result so no code path
        // can call success() twice on the same Result object.
        val prev = pendingStartResult
        pendingStartResult = result
        // If there was a previous pending result that was never resolved
        // (e.g. the user double-tapped Start), resolve it as a cancelled
        // operation so Android's channel handler doesn't throw
        // IllegalStateException("Reply already submitted").
        if (prev != null) {
            prev.success(null)
        }

        val intent = Intent(context, MwendoTrackingService::class.java)
        try {
            ContextCompat.startForegroundService(context, intent)
        } catch (e: Exception) {
            e.printStackTrace()
            pendingStartResult?.error("FOREGROUND_START_FAILED", e.message, null)
            pendingStartResult = null
            return
        }

        if (!bound) {
            context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
            // onServiceConnected will call pendingStartResult.success() once
            // the service is ready.
        } else if (service != null) {
            // Already bound and service is available — respond immediately.
            service!!.start(pendingProfile)
            handOverFromWarmUp(service!!)
            pendingStartResult?.success(mapOf("activity_id" to service!!.activityId))
            pendingStartResult = null
        } else {
            // bound == true but service is null: we're in the window between
            // onServiceDisconnected and a re-bind. Re-bind explicitly so
            // onServiceConnected fires and resolves pendingStartResult.
            context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        }
    }

    private fun stopService() {
        service?.setListener(null)
        if (bound) {
            try {
                context.unbindService(connection)
            } catch (_: Exception) {
                // already unbound
            }
            bound = false
        }
        context.stopService(Intent(context, MwendoTrackingService::class.java))
        service = null
    }

    override fun onLocation(point: Map<String, Any?>) {
        eventSink?.success(point)
    }

    /** Starts (or keeps) the warm-up request. Returns false without permission. */
    private fun warmUp(): Boolean {
        if (bound && service != null) return true // already recording: GPS is on
        val client = fused ?: LocationServices.getFusedLocationProviderClient(context).also { fused = it }
        return try {
            // Instant: the system's cached position (often seconds old).
            client.lastLocation.addOnSuccessListener { loc ->
                if (loc != null && previewCallback != null) {
                    if (latestPreview == null) latestPreview = loc
                    emitPreview(loc)
                }
            }
            if (previewCallback == null) {
                val cb = object : LocationCallback() {
                    override fun onLocationResult(result: LocationResult) {
                        for (loc in result.locations) {
                            latestPreview = loc
                            emitPreview(loc)
                        }
                    }
                }
                previewCallback = cb
                val request = LocationRequest.Builder(1000L)
                    .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                    .setMinUpdateIntervalMillis(1000L)
                    .setWaitForAccurateLocation(false)
                    .setMaxUpdateDelayMillis(0)
                    .build()
                client.requestLocationUpdates(request, ContextCompat.getMainExecutor(context), cb)
            }
            true
        } catch (e: SecurityException) {
            previewCallback = null
            false
        } catch (e: Exception) {
            e.printStackTrace()
            previewCallback = null
            false
        }
    }

    private fun stopWarmUp() {
        previewCallback?.let { cb -> fused?.removeLocationUpdates(cb) }
        previewCallback = null
    }

    private fun emitPreview(loc: Location) {
        val map = MwendoTrackingService.locationToMap(loc).toMutableMap()
        map["preview"] = true
        eventSink?.success(map)
    }

    /**
     * Recording just started: give the run the freshest warm fix as its first
     * point (if it is recent), then drop the warm-up request. The service's own
     * high-accuracy request is already registered, so the GNSS stays locked —
     * no cold start in between.
     */
    private fun handOverFromWarmUp(svc: MwendoTrackingService) {
        val warm = latestPreview
        if (warm != null && previewCallback != null) {
            val ageMs = (SystemClock.elapsedRealtimeNanos() - warm.elapsedRealtimeNanos) / 1_000_000
            if (ageMs in 0..10_000 && warm.hasAccuracy() && warm.accuracy <= 30f) {
                svc.seed(warm)
            }
        }
        stopWarmUp()
        latestPreview = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopWarmUp()
        // Do not stop the foreground service here: it must survive a transient
        // Flutter engine detach so a background run keeps recording. It is torn
        // down only by an explicit `stop()` from Dart.
        eventSink = null
    }
}
