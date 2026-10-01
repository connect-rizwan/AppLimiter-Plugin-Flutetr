package io.github.connectrizwan.app_limiter

import android.content.Context
import android.content.SharedPreferences

/**
 * Persists the blocking configuration shared by the plugin, the blocking service
 * and the boot receiver.
 *
 * - [isActive]: master switch; the blocking service runs only while this is true.
 * - [blockAll]: block every launchable user-installed app.
 * - [blockedPackages]: packages blocked individually.
 */
internal class BlockingStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    init {
        migrateLegacyBlockAll()
    }

    var isActive: Boolean
        get() = prefs.getBoolean(KEY_ACTIVE, false)
        set(value) = prefs.edit().putBoolean(KEY_ACTIVE, value).apply()

    var blockAll: Boolean
        get() = prefs.getBoolean(KEY_BLOCK_ALL, false)
        set(value) = prefs.edit().putBoolean(KEY_BLOCK_ALL, value).apply()

    var enterpriseModeEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENTERPRISE_MODE, false)
        set(value) = prefs.edit().putBoolean(KEY_ENTERPRISE_MODE, value).apply()

    val blockedPackages: Set<String>
        get() = prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet())
            .orEmpty()
            .filter { it.isNotBlank() }
            .toSet()

    /** True when there is at least one thing to block. */
    val hasTargets: Boolean
        get() = blockAll || blockedPackages.isNotEmpty()

    fun addPackage(packageName: String) {
        prefs.edit().putStringSet(KEY_BLOCKED_PACKAGES, blockedPackages + packageName).apply()
    }

    fun removePackage(packageName: String) {
        prefs.edit().putStringSet(KEY_BLOCKED_PACKAGES, blockedPackages - packageName).apply()
    }

    fun setBlockedPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_BLOCKED_PACKAGES, packages).apply()
    }

    /**
     * Versions up to 0.0.4 had no per-package list: `Blocking = true` meant
     * "block every app". Keep that meaning for users upgrading mid-block.
     */
    private fun migrateLegacyBlockAll() {
        if (prefs.contains(KEY_BLOCK_ALL)) return
        val legacyBlockAll = prefs.getBoolean(KEY_ACTIVE, false) && blockedPackages.isEmpty()
        prefs.edit().putBoolean(KEY_BLOCK_ALL, legacyBlockAll).apply()
    }

    companion object {
        const val PREFS_NAME = "app_settings"
        const val KEY_ACTIVE = "Blocking"
        const val KEY_BLOCK_ALL = "block_all"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_ENTERPRISE_MODE = "enterprise_mode_enabled"
    }
}
