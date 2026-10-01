package io.github.connectrizwan.app_limiter

import android.Manifest
import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * AppLimiterPlugin: Main plugin class that handles the communication between Flutter and Android
 *
 * This plugin provides functionality for:
 * - Getting platform version
 * - Managing app usage permissions
 * - Blocking and unblocking apps
 * - Listing installed apps
 *
 * Implements:
 * - FlutterPlugin: For plugin registration and lifecycle
 * - MethodCallHandler: For handling method calls from Flutter
 * - ActivityAware: For accessing Activity context and permissions
 */
class AppLimiterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var store: BlockingStore
    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity?
        get() = activityBinding?.activity

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    private var executor: ExecutorService? = null

    /** Flutter call waiting for the user to return from a permission screen. */
    private var pendingPermissionResult: Result? = null

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

    /** Returns the packages that could not be (un)suspended. */
    private fun setPackagesSuspended(packageNames: List<String>, suspended: Boolean): Set<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return packageNames.toSet()
        }

        return try {
            getDevicePolicyManager().setPackagesSuspended(
                getAdminComponent(),
                packageNames.toTypedArray(),
                suspended,
            ).toSet()
        } catch (e: SecurityException) {
            packageNames.toSet()
        } catch (e: IllegalArgumentException) {
            packageNames.toSet()
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

    private fun permissionStatus(): Map<String, Boolean> {
        return mapOf(
            PERMISSION_OVERLAY to BlockAppService.hasOverlayPermission(context),
            PERMISSION_USAGE_ACCESS to
                (BlockAppService.hasUsageStatsPermission(context) && checkQueryAllPackagesPermission()),
            PERMISSION_NOTIFICATIONS to hasNotificationPermission(),
        )
    }

    /** Next permission to ask for: required ones first, then notifications. */
    private fun nextMissingPermission(): String? {
        val status = permissionStatus()
        return listOf(PERMISSION_OVERLAY, PERMISSION_USAGE_ACCESS, PERMISSION_NOTIFICATIONS)
            .firstOrNull { status[it] == false }
    }

    private fun requestPermission(call: MethodCall, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "requestPermission needs a foreground activity.", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "Another permission request is still open.", null)
            return
        }

        val permission = call.argument<String>("permission") ?: nextMissingPermission()
        if (permission == null || permissionStatus()[permission] == true) {
            result.success(permissionStatus())
            return
        }

        try {
            when (permission) {
                PERMISSION_OVERLAY -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                        result.success(permissionStatus())
                        return
                    }
                    pendingPermissionResult = result
                    currentActivity.startActivityForResult(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + currentActivity.packageName),
                        ),
                        OVERLAY_REQUEST_CODE,
                    )
                }
                PERMISSION_USAGE_ACCESS -> {
                    pendingPermissionResult = result
                    currentActivity.startActivityForResult(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
                        USAGE_ACCESS_REQUEST_CODE,
                    )
                }
                PERMISSION_NOTIFICATIONS -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(permissionStatus())
                        return
                    }
                    pendingPermissionResult = result
                    currentActivity.requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        NOTIFICATION_REQUEST_CODE,
                    )
                }
                else -> result.error("INVALID_ARGUMENT", "Unknown permission: $permission", null)
            }
        } catch (e: ActivityNotFoundException) {
            pendingPermissionResult = null
            result.error("UNSUPPORTED", "This device has no settings screen for $permission.", null)
        }
    }

    private fun completePendingPermissionRequest() {
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(permissionStatus())
        PluginEvents.emit("android_permission_status", permissionStatus())
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != OVERLAY_REQUEST_CODE && requestCode != USAGE_ACCESS_REQUEST_CODE) {
            return false
        }
        completePendingPermissionRequest()
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != NOTIFICATION_REQUEST_CODE) {
            return false
        }
        completePendingPermissionRequest()
        return true
    }

    private fun blockingState(): Map<String, Any> {
        return mapOf(
            "active" to (store.isActive && store.hasTargets),
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
    private fun ensureCanBlock(result: Result, allowEnterprise: Boolean = true): Boolean {
        if (hasRequiredPermissions() || (allowEnterprise && isEnterpriseModeEnabled())) {
            return true
        }
        result.error(
            "PERMISSION_DENIED",
            "Overlay and usage access permissions are required. Call requestPermission() first.",
            null,
        )
        return false
    }

    private fun packageNamesArgument(call: MethodCall, result: Result): List<String>? {
        val packageNames = call.argument<List<String>>("packageNames")
            ?.map { it.trim() }
            .orEmpty()
        if (packageNames.isEmpty() || packageNames.any { it.isEmpty() }) {
            result.error("INVALID_ARGUMENT", "packageNames must be a non-empty list of package names.", null)
            return null
        }
        return packageNames.distinct()
    }

    private fun getInstalledApps(call: MethodCall, result: Result) {
        val includeIcons = call.argument<Boolean>("includeIcons") ?: false
        val includeSystemApps = call.argument<Boolean>("includeSystemApps") ?: true
        val iconSize = (call.argument<Int>("iconSize") ?: 96).coerceIn(16, 512)
        val worker = executor ?: Executors.newSingleThreadExecutor().also { executor = it }

        worker.execute {
            try {
                val apps = InstalledApps.query(context, includeIcons, includeSystemApps, iconSize)
                mainHandler.post { result.success(apps) }
            } catch (e: Exception) {
                mainHandler.post { result.error("UNKNOWN", "Failed to list installed apps.", e.message) }
            }
        }
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

            "getPermissionStatus" -> {
                result.success(permissionStatus())
            }

            "requestPermission" -> {
                requestPermission(call, result)
            }

            "getBlockingState" -> {
                result.success(blockingState())
            }

            "blockApps" -> {
                val packageNames = packageNamesArgument(call, result) ?: return
                if (!ensureCanBlock(result)) return

                if (isEnterpriseModeEnabled()) {
                    val failed = setPackagesSuspended(packageNames, true)
                    if (failed.isNotEmpty()) {
                        result.error(
                            "ENTERPRISE_ACTION_FAILED",
                            "Failed to suspend packages in enterprise mode.",
                            failed.sorted(),
                        )
                        return
                    }
                }

                store.setBlockedPackages(store.blockedPackages + packageNames)
                syncService()
                result.success(null)
            }

            "unblockApps" -> {
                val packageNames = packageNamesArgument(call, result) ?: return

                val failed = if (isEnterpriseModeEnabled()) {
                    setPackagesSuspended(packageNames, false)
                } else {
                    emptySet()
                }

                store.setBlockedPackages(store.blockedPackages - (packageNames.toSet() - failed))
                syncService()

                if (failed.isNotEmpty()) {
                    result.error(
                        "ENTERPRISE_ACTION_FAILED",
                        "Failed to unsuspend packages in enterprise mode.",
                        failed.sorted(),
                    )
                } else {
                    result.success(null)
                }
            }

            "blockAllApps" -> {
                if (!ensureCanBlock(result, allowEnterprise = false)) return
                store.blockAll = true
                syncService()
                result.success(null)
            }

            "unblockAllApps" -> {
                val stillSuspended = if (isEnterpriseModeEnabled() && store.blockedPackages.isNotEmpty()) {
                    setPackagesSuspended(store.blockedPackages.toList(), false)
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

            "getInstalledApps" -> {
                getInstalledApps(call, result)
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

            "isEnterpriseCapable" -> {
                result.success(isEnterpriseCapable())
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
        executor?.shutdown()
        executor = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        PluginEvents.sink = events
    }

    override fun onCancel(arguments: Any?) {
        PluginEvents.sink = null
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
        // The result will never arrive now; report the current status instead.
        completePendingPermissionRequest()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Keep any pending request: the recreated activity still delivers its result.
        detachActivity()
    }

    private companion object {
        const val OVERLAY_REQUEST_CODE = 1234
        const val NOTIFICATION_REQUEST_CODE = 1235
        const val USAGE_ACCESS_REQUEST_CODE = 1236

        const val PERMISSION_OVERLAY = "overlay"
        const val PERMISSION_USAGE_ACCESS = "usageAccess"
        const val PERMISSION_NOTIFICATIONS = "notifications"
    }
}
