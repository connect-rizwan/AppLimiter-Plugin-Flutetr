// Device Activity Monitor extension for app_limiter.
//
// Starts and ends iOS schedules and timed blocks while your app is closed.
// Copy this file and AppLimiterShared.swift into a "Device Activity Monitor
// Extension" target. See ios/extension_templates/README.md.

import DeviceActivity
import Foundation
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard
            let info = AppLimiterShared.scheduleInfo(from: activity),
            let schedule = AppLimiterShared.loadSchedules()[info.id]
        else { return }

        // The morning part of an overnight window belongs to the previous day.
        let now = Date()
        let startDay = info.part == "b"
            ? AppLimiterShared.isoWeekday(now.addingTimeInterval(-24 * 60 * 60))
            : AppLimiterShared.isoWeekday(now)
        guard schedule.weekdays.contains(startDay) else { return }

        AppLimiterShared.applyShield(schedule.selection, to: AppLimiterShared.scheduleStore(info.id))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity == AppLimiterShared.timedActivity {
            AppLimiterShared.clearShield(ManagedSettingsStore())
            AppLimiterShared.timedBlockUntil = nil
            return
        }

        guard let info = AppLimiterShared.scheduleInfo(from: activity) else { return }
        let schedule = AppLimiterShared.loadSchedules()[info.id]
        // The evening part of an overnight window continues in the morning part.
        if info.part == "a", schedule?.isOvernight == true { return }
        AppLimiterShared.clearShield(AppLimiterShared.scheduleStore(info.id))
    }
}
