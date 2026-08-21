package com.mwendo.mwendo_gps_engine

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 *
 * NOTE: this file was rewritten to match the plugin's real onMethodCall surface
 * (startRecording/pause/resume/stop/getPlatformMetadata) -- the previous version
 * tested a "getPlatformVersion" method that doesn't exist in MwendoGpsEnginePlugin
 * and would have failed if run (it hits the `else -> result.notImplemented()`
 * branch instead of `result.success(...)`). This rewrite was not executed against
 * a real Gradle/Android toolchain in the environment it was written in (no
 * `./gradlew` was available there) -- verify with `./gradlew testDebugUnitTest`
 * before relying on it in CI.
 *
 * Only the notImplemented() path is covered here without additional mocking,
 * since startRecording/pause/resume/stop/getPlatformMetadata all touch a real
 * Context (service binding, PackageManager) that onAttachedToEngine would
 * normally supply -- exercising those needs a mocked FlutterPluginBinding/
 * Context, which is a bigger lift than this test-hygiene fix, not added here.
 */

internal class MwendoGpsEnginePluginTest {
    @Test
    fun onMethodCall_unknownMethod_callsNotImplemented() {
        val plugin = MwendoGpsEnginePlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).notImplemented()
        Mockito.verify(mockResult, Mockito.never()).success(Mockito.any())
    }
}
