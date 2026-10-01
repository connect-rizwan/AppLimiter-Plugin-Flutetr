package io.github.connectrizwan.app_limiter

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class BlockScheduleTest {
  private fun minute(hour: Int, minute: Int = 0) = hour * 60 + minute

  private val workHours = BlockSchedule(
    id = "work",
    packages = setOf("com.game"),
    startMinute = minute(9),
    endMinute = minute(17),
    days = setOf(1, 2, 3, 4, 5),
  )

  private val night = BlockSchedule(
    id = "night",
    allApps = true,
    startMinute = minute(22),
    endMinute = minute(7),
    days = setOf(5), // Friday night into Saturday morning
  )

  @Test
  fun daytimeWindow_isActiveOnlyInsideHoursAndDays() {
    assertTrue(workHours.isActiveAt(1, minute(9)))
    assertTrue(workHours.isActiveAt(5, minute(16, 59)))
    assertFalse(workHours.isActiveAt(1, minute(17))) // end is exclusive
    assertFalse(workHours.isActiveAt(1, minute(8, 59)))
    assertFalse(workHours.isActiveAt(6, minute(12))) // Saturday
  }

  @Test
  fun overnightWindow_continuesIntoNextDay() {
    assertTrue(night.isActiveAt(5, minute(22)))
    assertTrue(night.isActiveAt(5, minute(23, 59)))
    assertTrue(night.isActiveAt(6, minute(0)))
    assertTrue(night.isActiveAt(6, minute(6, 59)))
    assertFalse(night.isActiveAt(6, minute(7)))
    assertFalse(night.isActiveAt(6, minute(22))) // Saturday night is not scheduled
    assertFalse(night.isActiveAt(5, minute(3))) // Thursday night is not scheduled
  }

  @Test
  fun overnightWindow_wrapsFromSundayToMonday() {
    val sundayNight = night.copy(days = setOf(7))
    assertTrue(sundayNight.isActiveAt(1, minute(2)))
  }

  @Test
  fun equalStartAndEnd_meansWholeDay() {
    val allDay = workHours.copy(startMinute = 0, endMinute = 0, days = setOf(3))
    assertTrue(allDay.isActiveAt(3, 0))
    assertTrue(allDay.isActiveAt(3, minute(23, 59)))
    assertFalse(allDay.isActiveAt(4, 0))
  }

  @Test
  fun fromMap_roundTripsToMap() {
    assertEquals(night, BlockSchedule.fromMap(night.toMap()))
    assertEquals(workHours, BlockSchedule.fromMap(workHours.toMap()))
  }

  @Test
  fun fromMap_rejectsInvalidSchedules() {
    val valid = workHours.toMap()
    assertNull(BlockSchedule.fromMap(valid - "id"))
    assertNull(BlockSchedule.fromMap(valid + ("startMinute" to 24 * 60)))
    assertNull(BlockSchedule.fromMap(valid + ("packages" to emptyList<String>())))
  }

  @Test
  fun fromMap_defaultsToEveryDay() {
    val schedule = BlockSchedule.fromMap(workHours.toMap() - "weekdays")
    assertEquals(BlockSchedule.ALL_DAYS, schedule?.days)
  }
}

internal class BlockTargetsTest {
  private val social = BlockSchedule(
    id = "social",
    packages = setOf("com.social"),
    startMinute = 0,
    endMinute = 0,
  )
  private val allButMaps = BlockSchedule(
    id = "focus",
    allApps = true,
    except = setOf("com.maps", "com.mail"),
    startMinute = 0,
    endMinute = 0,
  )
  private val inactive = BlockSchedule(
    id = "later",
    packages = setOf("com.video"),
    startMinute = 600,
    endMinute = 660,
  )

  private fun resolve(
    blockAll: Boolean = false,
    blocked: Set<String> = emptySet(),
    allowed: Set<String> = emptySet(),
    schedules: List<BlockSchedule> = emptyList(),
  ) = BlockTargets.resolve(blockAll, blocked, allowed, schedules, day = 1, minuteOfDay = 60)

  @Test
  fun nothingConfigured_blocksNothing() {
    assertFalse(resolve().isBlocking)
  }

  @Test
  fun activeSchedules_addToManualBlocks() {
    val targets = resolve(blocked = setOf("com.game"), schedules = listOf(social, inactive))
    assertEquals(setOf("com.game", "com.social"), targets.blockedPackages)
    assertEquals(setOf("social"), targets.activeScheduleIds)
    assertFalse(targets.blockAll)
  }

  @Test
  fun scheduledBlockAll_usesItsAllowlist() {
    val targets = resolve(schedules = listOf(allButMaps))
    assertTrue(targets.blockAll)
    assertEquals(setOf("com.maps", "com.mail"), targets.allowedPackages)
  }

  @Test
  fun overlappingBlockAll_onlyAllowsAppsAllowedByBoth() {
    val targets = resolve(blockAll = true, allowed = setOf("com.mail", "com.chat"), schedules = listOf(allButMaps))
    assertEquals(setOf("com.mail"), targets.allowedPackages)
  }

  @Test
  fun expiredKeys_returnsEndedEntriesOnly() {
    val expiries = mapOf("a" to 100L, "b" to 200L, "c" to 300L)
    assertEquals(setOf("a", "b"), expiredKeys(expiries, 200L))
    assertTrue(expiredKeys(expiries, 50L).isEmpty())
  }
}
