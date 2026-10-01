package io.github.connectrizwan.app_limiter

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists the blocking configuration shared by the plugin, the blocking service
 * and the boot receiver.
 *
 * - [isActive]: master switch; the blocking service runs only while this is true.
 * - [blockAll]: block every launchable user-installed app.
 * - [blockedPackages]: packages blocked individually.
 * - [allowedPackages]: packages left usable while [blockAll] is on.
 * - [blockedUntil] / [blockAllUntil]: end times of timed blocks.
 * - [schedules]: recurring block windows.
 */
internal class BlockingStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val expiryPrefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(EXPIRY_PREFS_NAME, Context.MODE_PRIVATE)
    private val schedulePrefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(SCHEDULE_PREFS_NAME, Context.MODE_PRIVATE)

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

    val allowedPackages: Set<String>
        get() = prefs.getStringSet(KEY_ALLOWED_PACKAGES, emptySet())
            .orEmpty()
            .filter { it.isNotBlank() }
            .toSet()

    fun setAllowedPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_ALLOWED_PACKAGES, packages).apply()
    }

    /** True when there is at least one manual block. */
    val hasTargets: Boolean
        get() = blockAll || blockedPackages.isNotEmpty()

    /** True when the blocking service has work: manual blocks or schedules. */
    val shouldRun: Boolean
        get() = hasTargets || hasSchedules

    // Timed blocks

    /** End time (epoch ms) of each timed package block. */
    val blockedUntil: Map<String, Long>
        get() = expiryPrefs.all.mapNotNull { (key, value) ->
            (value as? Long)?.let { key to it }
        }.toMap()

    fun setPackageExpiry(packageName: String, untilMs: Long?) {
        expiryPrefs.edit().apply {
            if (untilMs == null) remove(packageName) else putLong(packageName, untilMs)
        }.apply()
    }

    var blockAllUntil: Long?
        get() = if (prefs.contains(KEY_BLOCK_ALL_UNTIL)) prefs.getLong(KEY_BLOCK_ALL_UNTIL, 0) else null
        set(value) = prefs.edit().apply {
            if (value == null) remove(KEY_BLOCK_ALL_UNTIL) else putLong(KEY_BLOCK_ALL_UNTIL, value)
        }.apply()

    fun clearExpiries() {
        expiryPrefs.edit().clear().apply()
        blockAllUntil = null
    }

    /** Ended timed blocks removed by [pruneExpired]. */
    data class Expired(val packages: Set<String>, val blockAll: Boolean) {
        val isEmpty: Boolean get() = packages.isEmpty() && !blockAll
    }

    /** Removes timed blocks that have ended. */
    fun pruneExpired(nowMs: Long): Expired {
        val packages = expiredKeys(blockedUntil, nowMs)
        if (packages.isNotEmpty()) {
            setBlockedPackages(blockedPackages - packages)
            expiryPrefs.edit().apply { packages.forEach { remove(it) } }.apply()
        }
        val blockAllEnded = blockAllUntil?.let { it <= nowMs } == true
        if (blockAllEnded) {
            blockAll = false
            setAllowedPackages(emptySet())
            blockAllUntil = null
        }
        return Expired(packages, blockAllEnded)
    }

    // Schedules

    val schedules: List<BlockSchedule>
        get() = schedulePrefs.all.values.mapNotNull { value ->
            try {
                BlockSchedule.fromMap(jsonToMap(JSONObject(value as String)))
            } catch (e: Exception) {
                null
            }
        }.sortedBy { it.id }

    val hasSchedules: Boolean
        get() = schedulePrefs.all.isNotEmpty()

    fun putSchedule(schedule: BlockSchedule) {
        schedulePrefs.edit().putString(schedule.id, JSONObject(schedule.toMap()).toString()).apply()
    }

    fun removeSchedule(id: String) {
        schedulePrefs.edit().remove(id).apply()
    }

    fun clearSchedules() {
        schedulePrefs.edit().clear().apply()
    }

    /** Effective blocking right now (manual blocks plus active schedules). */
    fun targets(nowMs: Long): BlockTargets {
        val (day, minute) = localDayAndMinute(nowMs)
        return BlockTargets.resolve(blockAll, blockedPackages, allowedPackages, schedules, day, minute)
    }

    private fun jsonToMap(json: JSONObject): Map<String, Any?> {
        return json.keys().asSequence().associateWith { key ->
            when (val value = json.get(key)) {
                is JSONArray -> (0 until value.length()).map { value.get(it) }
                else -> value
            }
        }
    }

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
        const val KEY_ALLOWED_PACKAGES = "allowed_packages"
        const val KEY_ENTERPRISE_MODE = "enterprise_mode_enabled"
        const val KEY_BLOCK_ALL_UNTIL = "block_all_until"
        const val EXPIRY_PREFS_NAME = "app_limiter_expiry"
        const val SCHEDULE_PREFS_NAME = "app_limiter_schedules"
    }
}
