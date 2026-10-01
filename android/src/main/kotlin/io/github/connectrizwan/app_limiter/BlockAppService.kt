package io.github.connectrizwan.app_limiter

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat

const val CHANNEL_ID = "BlockAppService_Channel_ID"
const val NOTIFICATION_ID = 1

/**
 * Foreground service that covers blocked apps with an overlay while they are
 * in the foreground.
 *
 * Runs as a `specialUse` foreground service: Android 14+ requires a type, and
 * `dataSync` is capped at 6 hours a day on Android 15 and may not be started
 * from BOOT_COMPLETED.
 */
class BlockAppService : Service() {
    private lateinit var store: BlockingStore
    private lateinit var blockScreenStore: BlockScreenStore
    private lateinit var windowManager: WindowManager
    private lateinit var tracker: ForegroundAppTracker
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    private val candidateCache = HashMap<String, Boolean>()
    private var protectedPackages: Set<String> = emptySet()
    private var blockAllExemptPackages: Set<String> = emptySet()
    private var lastHomeLaunchMs = 0L

    /** Blocked app currently covered, so "opened" is reported once per visit. */
    private var currentBlockedPackage: String? = null

    private val overlayParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        },
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
        PixelFormat.TRANSLUCENT,
    )

    private val blockingLoop = object : Runnable {
        override fun run() {
            if (tick()) {
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = BlockingStore(this)
        blockScreenStore = BlockScreenStore(this)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        tracker = ForegroundAppTracker(::queryForegroundEvents)
    }

    override fun onBind(intent: Intent): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Every startForegroundService() call must be answered with startForeground().
        if (!startInForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!store.isActive || !store.hasTargets) {
            stopSelf()
            return START_NOT_STICKY
        }

        // Pick up configuration changes (packages added/removed) and re-evaluate now.
        protectedPackages = resolveProtectedPackages()
        blockAllExemptPackages = resolveBlockAllExemptPackages()
        candidateCache.clear()
        handler.removeCallbacks(blockingLoop)
        handler.post(blockingLoop)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(blockingLoop)
        hideOverlay()
        super.onDestroy()
    }

    /** Returns false when the loop should stop. */
    private fun tick(): Boolean {
        if (!store.isActive || !store.hasTargets) {
            stopSelf()
            return false
        }

        if (!hasOverlayPermission(this) || !hasUsageStatsPermission(this)) {
            Log.w(TAG, "Required permission revoked; stopping blocking.")
            store.isActive = false
            PluginEvents.emit(
                "android_blocking_stopped",
                mapOf("reason" to "permission_revoked"),
            )
            stopSelf()
            return false
        }

        if (isDeviceLocked()) {
            hideOverlay()
            return true
        }

        val foregroundPackage = tracker.update(System.currentTimeMillis())
        val block = foregroundPackage != null && BlockPolicy.shouldBlock(
            packageName = foregroundPackage,
            protectedPackages = protectedPackages,
            blockAll = store.blockAll,
            blockedPackages = store.blockedPackages,
            allowedPackages = store.allowedPackages,
            isBlockAllCandidate = ::isBlockAllCandidate,
        )
        if (block) {
            if (currentBlockedPackage != foregroundPackage) {
                currentBlockedPackage = foregroundPackage
                PluginEvents.emit(
                    "android_blocked_app_opened",
                    mapOf("packageName" to foregroundPackage),
                )
            }
            showOverlay()
            if (foregroundPackage in BlockPolicy.OVERLAY_HIDING_PACKAGES) {
                goHome()
            }
        } else {
            currentBlockedPackage = null
            hideOverlay()
        }
        return true
    }

    /**
     * Settings and other security-sensitive system apps hide third-party overlays
     * (HIDE_NON_SYSTEM_OVERLAY_WINDOWS), so the overlay would only flash. The
     * window is hidden by the compositor without notifying the view, so these
     * apps are handled by sending the user to the home screen instead.
     */
    private fun goHome() {
        val now = System.currentTimeMillis()
        if (now - lastHomeLaunchMs < HOME_RELAUNCH_INTERVAL_MS) return
        lastHomeLaunchMs = now
        try {
            startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Unable to leave blocked app", e)
        }
    }

    private fun startInForeground(): Boolean {
        return try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: Exception) {
            // e.g. ForegroundServiceStartNotAllowedException when started from the background.
            Log.e(TAG, "Unable to start blocking service in the foreground", e)
            PluginEvents.emit(
                "android_blocking_stopped",
                mapOf("reason" to "foreground_start_failed", "message" to e.message),
            )
            false
        }
    }

    private fun buildNotification(): android.app.Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.app_limiter_notification_channel),
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setShowBadge(false)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(
                blockScreenStore.notificationTitle ?: getString(R.string.app_limiter_notification_title),
            )
            .setContentText(
                blockScreenStore.notificationText ?: getString(R.string.app_limiter_notification_text),
            )
            .setSmallIcon(R.drawable.ic_hourglass)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun queryForegroundEvents(
        beginMs: Long,
        endMs: Long,
    ): List<ForegroundAppTracker.ForegroundEvent> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageStatsManager.queryEvents(beginMs, endMs) ?: return emptyList()
        val result = ArrayList<ForegroundAppTracker.ForegroundEvent>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // MOVE_TO_FOREGROUND and ACTIVITY_RESUMED share the same value.
            @Suppress("DEPRECATION")
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                result.add(ForegroundAppTracker.ForegroundEvent(event.packageName, event.timeStamp))
            }
        }
        return result
    }

    /**
     * "Block all" covers every app with a launcher icon, preinstalled ones included
     * (YouTube, Gmail, ... are system apps on most phones), except [blockAllExemptPackages].
     */
    private fun isBlockAllCandidate(packageName: String): Boolean {
        return candidateCache.getOrPut(packageName) {
            packageName !in blockAllExemptPackages &&
                packageManager.getLaunchIntentForPackage(packageName) != null
        }
    }

    /** Apps kept usable during "block all": the phone dialer (emergency calls) and Settings. */
    private fun resolveBlockAllExemptPackages(): Set<String> {
        val exempt = mutableSetOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val telecom = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            telecom?.defaultDialerPackage?.let { exempt.add(it) }
        }
        @Suppress("DEPRECATION")
        packageManager.resolveActivity(Intent(Settings.ACTION_SETTINGS), PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName?.let { exempt.add(it) }
        return exempt
    }

    /** Packages that must never be covered, so the user can always leave a blocked app. */
    private fun resolveProtectedPackages(): Set<String> {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val homeActivities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                homeIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        // Settings declares a negative-priority FallbackHome used only during boot; skip such
        // entries or Settings would become unblockable.
        val launchers = homeActivities.filter { it.priority >= 0 }.map { it.activityInfo.packageName }

        @Suppress("DEPRECATION")
        val defaultLauncher = packageManager
            .resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo
            ?.packageName
            ?.takeIf { it != "android" } // "android" is the chooser, not a launcher

        return launchers.toSet() + listOfNotNull(defaultLauncher) + packageName + SYSTEM_UI_PACKAGE
    }

    private fun isDeviceLocked(): Boolean {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguardManager.isKeyguardLocked
    }

    private fun showOverlay() {
        if (overlayView != null) return
        try {
            val view = LayoutInflater.from(this).inflate(R.layout.block_overlay, null)
            val config = blockScreenStore.load()
            BlockScreen.apply(
                view = view,
                config = config,
                icon = blockScreenStore.loadIcon(),
                hostAppLabel = applicationInfo.loadLabel(packageManager).toString(),
                onButtonClick = { onBlockScreenButton(config) },
            )
            windowManager.addView(view, overlayParams)
            overlayView = view
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }

    private fun onBlockScreenButton(config: BlockScreenConfig) {
        try {
            startActivity(BlockScreen.buttonIntent(this, config))
        } catch (e: Exception) {
            Log.e(TAG, "Unable to handle block screen button", e)
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        overlayView = null
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide overlay", e)
        }
    }

    companion object {
        private const val TAG = "BlockAppService"
        private const val POLL_INTERVAL_MS = 500L
        private const val HOME_RELAUNCH_INTERVAL_MS = 1_500L
        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"

        fun start(context: Context) {
            val intent = Intent(context, BlockAppService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BlockAppService::class.java))
        }

        fun hasOverlayPermission(context: Context): Boolean {
            return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)
        }

        fun hasUsageStatsPermission(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            @Suppress("DEPRECATION")
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName,
            )
            return mode == AppOpsManager.MODE_ALLOWED
        }
    }
}
