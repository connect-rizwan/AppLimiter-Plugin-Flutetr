package io.github.connectrizwan.app_limiter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class AppLimiterPluginTest {
  @Test
  fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
    val plugin = AppLimiterPlugin()

    val call = MethodCall("getPlatformVersion", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
  }

  @Test
  fun onMethodCall_blockAppsWithBlankPackage_returnsInvalidArgument() {
    val plugin = AppLimiterPlugin()
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

    plugin.onMethodCall(
      MethodCall("blockApps", mapOf("packageNames" to listOf("com.a", "  "))),
      mockResult,
    )

    Mockito.verify(mockResult).error(eq("INVALID_ARGUMENT"), anyString(), any())
    Mockito.verify(mockResult, Mockito.never()).success(any())
  }

  @Test
  fun onMethodCall_unblockAppsWithoutPackages_returnsInvalidArgument() {
    val plugin = AppLimiterPlugin()
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

    plugin.onMethodCall(MethodCall("unblockApps", emptyMap<String, Any>()), mockResult)

    Mockito.verify(mockResult).error(eq("INVALID_ARGUMENT"), anyString(), any())
  }

  @Test
  fun onMethodCall_requestPermissionWithoutActivity_returnsNoActivity() {
    val plugin = AppLimiterPlugin()
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

    plugin.onMethodCall(MethodCall("requestPermission", emptyMap<String, Any>()), mockResult)

    Mockito.verify(mockResult).error(eq("NO_ACTIVITY"), anyString(), any())
  }

  @Test
  fun onMethodCall_unknownMethod_returnsNotImplemented() {
    val plugin = AppLimiterPlugin()
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

    plugin.onMethodCall(MethodCall("doesNotExist", null), mockResult)

    Mockito.verify(mockResult).notImplemented()
  }
}
