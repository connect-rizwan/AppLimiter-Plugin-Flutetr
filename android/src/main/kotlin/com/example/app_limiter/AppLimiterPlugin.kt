package com.example.app_limiter

import android.Manifest
import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * AppLimiterPlugin: Main plugin class that handles the communication between Flutter and Android
 *
 * This plugin provides functionality for:
 * - Getting platform version
 * - Managing app usage permissions
 * - Blocking and unblocking apps
 * - Handling system overlay permissions
 *
 * Implements:
 * - FlutterPlugin: For plugin registration and lifecycle
 * - MethodCallHandler: For handling method calls from Flutter
 * - ActivityAware: For accessing Activity context and permissions
 */
class AppLimiterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var store: BlockingStore
    private var activity: Activity? = null

    private fun getDevicePolicyManager(): DevicePolicyManager {
        return context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    private fun getAdminComponent(): ComponentName {
        return ComponentName(context, EnterpriseAdminReceiver::class.java)
    }

    private fun isEnterpriseCapable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        return getDevicePolicyManager().isDeviceOwnerApp(context.packageName)
    }

    private fun isEnterpriseModeEnabled(): Boolean {
        return store.enterpriseModeEnabled && isEnterpriseCapable()
    }

    private fun setPackageSuspended(packageName: String, suspended: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }

        return try {
            val unsuspendable = getDevicePolicyManager().setPackagesSuspended(
                getAdminComponent(),
                arrayOf(packageName),
                suspended,
            )
            unsuspendable.none { it == packageName }
        } catch (e: SecurityException) {
            false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    /**
     * Checks if the app has permission to query all packages
     * Required for Android 11+ to access package information
     */
    private fun checkQueryAllPackagesPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            PackageManager.PERMISSION_GRANTED == context.checkSelfPermission(Manifest.permission.QUERY_ALL_PACKAGES)
        } else {
            true
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            PackageManager.PERMISSION_GRANTED == context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            true
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        return BlockAppService.hasOverlayPermission(context) &&
            BlockAppService.hasUsageStatsPermission(context) &&
            checkQueryAllPackagesPermission()
    }

    private fun requestDrawOverlayPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + activity.packageName),
            )
            activity.startActivityForResult(intent, OVERLAY_REQUEST_CODE)
        }
    }

    private fun requestUsageStatsPermission(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun blockingState(): Map<String, Any> {
        return mapOf(
            "active" to store.isActive,
            "blockAll" to store.blockAll,
            "blockedPackages" to store.blockedPackages.sorted(),
        )
    }

    /** Starts or refreshes the blocking service, or stops it when nothing is left to block. */
    private fun syncService() {
        store.isActive = store.hasTargets
        // In enterprise mode without overlay access, suspension alone does the blocking.
        if (store.isActive && hasRequiredPermissions()) {
            BlockAppService.start(context)
        } else {
            BlockAppService.stop(context)
        }
        PluginEvents.emit("android_blocking_state_changed", blockingState())
    }

    /** Overlay blocking needs these permissions; enterprise mode suspends packages instead. */
    private fun ensureCanBlock(result: Result): Boolean {
        if (hasRequiredPermissions() || isEnterpriseModeEnabled()) {
            return true
        }
        result.error(
            "PERMISSION_DENIED",
            "Overlay and usage access permissions are required. Call requestAndroidPermission() first.",
            null,
        )
        return false
    }

    private fun packageArgument(call: MethodCall, result: Result): String? {
        val packageName = call.argument<String>("packageName")?.trim().orEmpty()
        if (packageName.isEmpty()) {
            result.error("INVALID_ARGUMENT", "packageName must not be empty.", null)
            return null
        }
        return packageName
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        store = BlockingStore(context)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app_limiter")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "app_limiter/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }

            "blockApp" -> {
                val packageName = packageArgument(call, result) ?: return
                if (!ensureCanBlock(result)) return

                if (isEnterpriseModeEnabled() && !setPackageSuspended(packageName, true)) {
                    result.error(
                        "ENTERPRISE_ACTION_FAILED",
                        "Failed to suspend package in enterprise mode.",
                        packageName,
                    )
                    return
                }

                store.addPackage(packageName)
                syncService()
                result.success(null)
            }

            "unblockApp" -> {
                val packageName = packageArgument(call, result) ?: return

                if (isEnterpriseModeEnabled() && !setPackageSuspended(packageName, false)) {
                    result.error(
                        "ENTERPRISE_ACTION_FAILED",
                        "Failed to unsuspend package in enterprise mode.",
                        packageName,
                    )
                    return
                }

                store.removePackage(packageName)
                syncService()
                result.success(null)
            }

            "blockAllApps" -> {
                if (!hasRequiredPermissions()) {
                    ensureCanBlock(result)
                    return
                }
                store.blockAll = true
                syncService()
                result.success(null)
            }

            "unblockAllApps" -> {
                val stillSuspended = if (isEnterpriseModeEnabled()) {
                    store.blockedPackages.filterNot { setPackageSuspended(it, false) }.toSet()
                } else {
                    emptySet()
                }

                store.blockAll = false
                store.setBlockedPackages(stillSuspended)
                syncService()

                if (stillSuspended.isNotEmpty()) {
                    result.error(
                        "ENTERPRISE_ACTION_FAILED",
                        "Failed to unsuspend some packages in enterprise mode.",
                        stillSuspended.sorted(),
                    )
                } else {
                    result.success(null)
                }
            }

            "getBlockedApps" -> {
                result.success(store.blockedPackages.sorted())
            }

            "isBlockingActive" -> {
                result.success(store.isActive && store.hasTargets)
            }

            "checkPermission" -> {
                result.success(hasRequiredPermissions())
            }

            "requestAuthorization" -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("NO_ACTIVITY", "Activity is null", null)
                    return
                }

                when {
                    !BlockAppService.hasOverlayPermission(context) -> {
                        requestDrawOverlayPermission(currentActivity)
                        result.success("overlay_permission_requested")
                    }
                    !BlockAppService.hasUsageStatsPermission(context) -> {
                        requestUsageStatsPermission(currentActivity)
                        result.success("usage_stats_permission_requested")
                    }
                    !hasNotificationPermission() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                        currentActivity.requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            NOTIFICATION_REQUEST_CODE,
                        )
                        result.success("notification_permission_requested")
                    }
                    else -> {
                        result.success("all_permissions_granted")
                    }
                }
            }

            "getCapabilities" -> {
                result.success(
                    mapOf(
                        "platform" to "android",
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "enterpriseCapable" to isEnterpriseCapable(),
                        "enterpriseModeEnabled" to isEnterpriseModeEnabled(),
                        "usageStatsPermission" to BlockAppService.hasUsageStatsPermission(context),
                        "overlayPermission" to BlockAppService.hasOverlayPermission(context),
                        "notificationPermission" to hasNotificationPermission(),
                        "blockingActive" to (store.isActive && store.hasTargets),
                        "blockAll" to store.blockAll,
                        "blockedPackages" to store.blockedPackages.sorted(),
                    ),
                )
            }

            "setEnterpriseMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled && !isEnterpriseCapable()) {
                    result.error(
                        "ENTERPRISE_NOT_AVAILABLE",
                        "Device owner mode is not active on this device.",
                        null,
                    )
                    return
                }

                store.enterpriseModeEnabled = enabled
                result.success(null)
            }

            "isEnterpriseModeEnabled" -> {
                result.success(isEnterpriseModeEnabled())
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        PluginEvents.sink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        PluginEvents.sink = events
    }

    override fun onCancel(arguments: Any?) {
        PluginEvents.sink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    private companion object {
        const val OVERLAY_REQUEST_CODE = 1234
        const val NOTIFICATION_REQUEST_CODE = 1235
    }
}
