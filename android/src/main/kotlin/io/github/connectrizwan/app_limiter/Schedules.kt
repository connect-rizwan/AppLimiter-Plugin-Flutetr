package io.github.connectrizwan.app_limiter

import java.util.Calendar

/**
 * A recurring daily block window.
 *
 * Days use ISO numbering (1 = Monday ... 7 = Sunday). When [endMinute] is not
 * after [startMinute] the window runs overnight into the next day; [days] then
 * refers to the day the window starts. Equal start and end mean the whole day.
 */
internal data class BlockSchedule(
    val id: String,
    val packages: Set<String> = emptySet(),
    val allApps: Boolean = false,
    val except: Set<String> = emptySet(),
    val startMinute: Int,
    val endMinute: Int,
    val days: Set<Int> = ALL_DAYS,
) {
    fun isActiveAt(day: Int, minuteOfDay: Int): Boolean {
        val previousDay = if (day == 1) 7 else day - 1
        return when {
            startMinute == endMinute -> day in days
            startMinute < endMinute -> day in days && minuteOfDay in startMinute until endMinute
            else -> (day in days && minuteOfDay >= startMinute) ||
                (previousDay in days && minuteOfDay < endMinute)
        }
    }

    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "packages" to packages.sorted(),
        "allApps" to allApps,
        "except" to except.sorted(),
        "startMinute" to startMinute,
        "endMinute" to endMinute,
        "weekdays" to days.sorted(),
    )

    companion object {
        val ALL_DAYS = (1..7).toSet()

        /** Returns null when the map is not a valid schedule. */
        fun fromMap(map: Map<*, *>): BlockSchedule? {
            val id = (map["id"] as? String)?.takeIf { it.isNotBlank() } ?: return null
            val start = (map["startMinute"] as? Number)?.toInt() ?: return null
            val end = (map["endMinute"] as? Number)?.toInt() ?: return null
            if (start !in 0 until MINUTES_PER_DAY || end !in 0 until MINUTES_PER_DAY) return null
            val days = (map["weekdays"] as? List<*>)
                ?.mapNotNull { (it as? Number)?.toInt() }
                ?.filter { it in 1..7 }
                ?.toSet()
                ?.takeIf { it.isNotEmpty() }
                ?: ALL_DAYS
            val packages = stringSet(map["packages"])
            val allApps = map["allApps"] as? Boolean ?: false
            if (!allApps && packages.isEmpty()) return null
            return BlockSchedule(
                id = id,
                packages = packages,
                allApps = allApps,
                except = stringSet(map["except"]),
                startMinute = start,
                endMinute = end,
                days = days,
            )
        }

        private fun stringSet(value: Any?): Set<String> {
            return (value as? List<*>)
                ?.mapNotNull { (it as? String)?.trim()?.takeIf(String::isNotEmpty) }
                ?.toSet()
                .orEmpty()
        }
    }
}

internal const val MINUTES_PER_DAY = 24 * 60

/** Current ISO weekday (1 = Monday) and minute of day in the device time zone. */
internal fun localDayAndMinute(nowMs: Long): Pair<Int, Int> {
    val calendar = Calendar.getInstance().apply { timeInMillis = nowMs }
    val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
    val isoDay = if (dayOfWeek == Calendar.SUNDAY) 7 else dayOfWeek - 1
    return isoDay to calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
}

/** What must be blocked right now, combining manual blocks and active schedules. */
internal data class BlockTargets(
    val blockAll: Boolean,
    val blockedPackages: Set<String>,
    val allowedPackages: Set<String>,
    val activeScheduleIds: Set<String>,
) {
    val isBlocking: Boolean
        get() = blockAll || blockedPackages.isNotEmpty()

    companion object {
        fun resolve(
            manualBlockAll: Boolean,
            manualBlocked: Set<String>,
            manualAllowed: Set<String>,
            schedules: Collection<BlockSchedule>,
            day: Int,
            minuteOfDay: Int,
        ): BlockTargets {
            val active = schedules.filter { it.isActiveAt(day, minuteOfDay) }

            // An app stays usable during block-all only if every block-all source allows it.
            val allowLists = buildList {
                if (manualBlockAll) add(manualAllowed)
                active.filter { it.allApps }.forEach { add(it.except) }
            }
            val allowed = allowLists.reduceOrNull { acc, set -> acc intersect set }.orEmpty()

            return BlockTargets(
                blockAll = allowLists.isNotEmpty(),
                blockedPackages = manualBlocked + active.flatMap { it.packages },
                allowedPackages = allowed,
                activeScheduleIds = active.map { it.id }.toSet(),
            )
        }
    }
}

/** Entries of [expiries] that ended at or before [nowMs]. */
internal fun expiredKeys(expiries: Map<String, Long>, nowMs: Long): Set<String> {
    return expiries.filterValues { it <= nowMs }.keys
}
