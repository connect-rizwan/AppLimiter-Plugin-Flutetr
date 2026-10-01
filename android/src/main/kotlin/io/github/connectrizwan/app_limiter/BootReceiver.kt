package io.github.connectrizwan.app_limiter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Restarts blocking after a reboot or an app update, if it was active before. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("BootReceiver", "onReceive: ${intent.action}")

        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val store = BlockingStore(context)
        if (!store.isActive || !store.hasTargets) {
            return
        }
        if (!BlockAppService.hasOverlayPermission(context) ||
            !BlockAppService.hasUsageStatsPermission(context)
        ) {
            return
        }

        try {
            BlockAppService.start(context)
        } catch (e: Exception) {
            Log.e("BootReceiver", "Unable to restart blocking service", e)
        }
    }
}
