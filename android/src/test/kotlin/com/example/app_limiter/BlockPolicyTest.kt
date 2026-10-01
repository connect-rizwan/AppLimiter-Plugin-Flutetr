package com.example.app_limiter

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class BlockPolicyTest {
  private val protectedPackages = setOf("com.host.app", "com.launcher")
  private val userApps = setOf("com.social", "com.game")

  private fun shouldBlock(
    packageName: String,
    blockAll: Boolean = false,
    blocked: Set<String> = emptySet(),
  ) = BlockPolicy.shouldBlock(packageName, protectedPackages, blockAll, blocked) { it in userApps }

  @Test
  fun explicitlyBlockedPackage_isBlocked() {
    assertTrue(shouldBlock("com.social", blocked = setOf("com.social")))
  }

  @Test
  fun packageNotInList_isNotBlocked_whenBlockAllIsOff() {
    assertFalse(shouldBlock("com.game", blocked = setOf("com.social")))
  }

  @Test
  fun blockAll_blocksUserApps_butNotSystemApps() {
    assertTrue(shouldBlock("com.game", blockAll = true))
    assertFalse(shouldBlock("com.android.settings", blockAll = true))
  }

  @Test
  fun protectedPackages_areNeverBlocked() {
    assertFalse(shouldBlock("com.host.app", blockAll = true, blocked = setOf("com.host.app")))
    assertFalse(shouldBlock("com.launcher", blockAll = true, blocked = setOf("com.launcher")))
  }

  @Test
  fun explicitlyBlockedSystemApp_isBlocked() {
    assertTrue(shouldBlock("com.android.settings", blocked = setOf("com.android.settings")))
  }
}

internal class ForegroundAppTrackerTest {
  private class FakeEvents {
    val events = mutableListOf<ForegroundAppTracker.ForegroundEvent>()
    val queries = mutableListOf<Pair<Long, Long>>()

    fun query(begin: Long, end: Long): List<ForegroundAppTracker.ForegroundEvent> {
      queries.add(begin to end)
      return events.filter { it.timestampMs in begin..end }
    }
  }

  @Test
  fun returnsNull_whenNoForegroundEventSeen() {
    val fake = FakeEvents()
    val tracker = ForegroundAppTracker(fake::query)
    assertNull(tracker.update(10_000))
  }

  @Test
  fun firstQuery_looksBackOverInitialWindow() {
    val fake = FakeEvents()
    val tracker = ForegroundAppTracker(fake::query, initialLookbackMs = 5_000)
    tracker.update(100_000)
    assertEquals(95_000L to 100_000L, fake.queries.single())
  }

  @Test
  fun keepsForegroundApp_whenNoNewEventsArrive() {
    // Regression: the overlay used to disappear once the blocked app had been
    // open longer than the 10 second query window.
    val fake = FakeEvents()
    fake.events.add(ForegroundAppTracker.ForegroundEvent("com.social", 1_000))
    val tracker = ForegroundAppTracker(fake::query)

    assertEquals("com.social", tracker.update(2_000))
    assertEquals("com.social", tracker.update(60_000))
    assertEquals("com.social", tracker.update(10 * 60_000))
  }

  @Test
  fun switchesToLatestForegroundApp() {
    val fake = FakeEvents()
    fake.events.add(ForegroundAppTracker.ForegroundEvent("com.social", 1_000))
    val tracker = ForegroundAppTracker(fake::query)
    tracker.update(2_000)

    fake.events.add(ForegroundAppTracker.ForegroundEvent("com.launcher", 2_500))
    fake.events.add(ForegroundAppTracker.ForegroundEvent("com.game", 2_800))
    assertEquals("com.game", tracker.update(3_000))
  }

  @Test
  fun laterQueries_overlapPreviousWindow() {
    val fake = FakeEvents()
    val tracker = ForegroundAppTracker(fake::query, overlapMs = 2_000)
    tracker.update(10_000)
    tracker.update(10_500)
    assertEquals(8_000L to 10_500L, fake.queries.last())
  }

  @Test
  fun eventRecordedLateWithinOverlap_isNotMissed() {
    val fake = FakeEvents()
    val tracker = ForegroundAppTracker(fake::query, overlapMs = 2_000)
    tracker.update(10_000)

    // Event timestamped just before the previous query end, delivered afterwards.
    fake.events.add(ForegroundAppTracker.ForegroundEvent("com.game", 9_900))
    assertEquals("com.game", tracker.update(10_500))
  }
}
