package io.github.connectrizwan.app_limiter

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build

/** Device owner (enterprise) package suspension, shared by the plugin and the service. */
internal object Enterprise {
    private fun devicePolicyManager(context: Context): DevicePolicyManager {
        return context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    fun isCapable(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        return devicePolicyManager(context).isDeviceOwnerApp(context.packageName)
    }

    fun isModeEnabled(context: Context, store: BlockingStore): Boolean {
        return store.enterpriseModeEnabled && isCapable(context)
    }

    /** Returns the packages that could not be (un)suspended. */
    fun setPackagesSuspended(context: Context, packageNames: List<String>, suspended: Boolean): Set<String> {
        if (packageNames.isEmpty()) return emptySet()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return packageNames.toSet()

        return try {
            devicePolicyManager(context).setPackagesSuspended(
                ComponentName(context, EnterpriseAdminReceiver::class.java),
                packageNames.toTypedArray(),
                suspended,
            ).toSet()
        } catch (e: SecurityException) {
            packageNames.toSet()
        } catch (e: IllegalArgumentException) {
            packageNames.toSet()
        }
    }
}
