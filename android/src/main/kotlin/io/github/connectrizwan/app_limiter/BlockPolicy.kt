package io.github.connectrizwan.app_limiter

/** Pure decision logic for whether a foreground package should be covered. */
internal object BlockPolicy {
    /**
     * System apps that hide third-party overlays (HIDE_NON_SYSTEM_OVERLAY_WINDOWS).
     * When blocked, the user is sent to the home screen instead.
     */
    val OVERLAY_HIDING_PACKAGES = setOf(
        "com.android.settings",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
    )

    /**
     * @param protectedPackages packages that must never be blocked (host app,
     *   home launcher, system UI) so the user can always get out.
     * @param isBlockAllCandidate whether [packageName] is a launchable,
     *   user-installed app; only consulted when [blockAll] is true.
     */
    fun shouldBlock(
        packageName: String,
        protectedPackages: Set<String>,
        blockAll: Boolean,
        blockedPackages: Set<String>,
        isBlockAllCandidate: (String) -> Boolean,
    ): Boolean {
        if (packageName in protectedPackages) return false
        if (packageName in blockedPackages) return true
        return blockAll && isBlockAllCandidate(packageName)
    }
}

/**
 * Tracks which app is in the foreground from usage events.
 *
 * Remembers the last known foreground app between polls, so an app that has
 * been open for a long time (and so has produced no recent events) is still
 * reported. Re-reading only a short recent window each poll is what made the
 * overlay disappear about 10 seconds after opening a blocked app.
 */
internal class ForegroundAppTracker(
    private val queryForegroundEvents: (beginMs: Long, endMs: Long) -> List<ForegroundEvent>,
    private val initialLookbackMs: Long = 60 * 60 * 1000L,
    private val overlapMs: Long = 2_000L,
) {
    data class ForegroundEvent(val packageName: String, val timestampMs: Long)

    private var lastQueryEndMs: Long? = null

    var foregroundPackage: String? = null
        private set

    fun update(nowMs: Long): String? {
        val beginMs = lastQueryEndMs?.let { it - overlapMs } ?: (nowMs - initialLookbackMs)
        val latest = queryForegroundEvents(beginMs, nowMs).maxByOrNull { it.timestampMs }
        if (latest != null) {
            foregroundPackage = latest.packageName
        }
        lastQueryEndMs = nowMs
        return foregroundPackage
    }
}
