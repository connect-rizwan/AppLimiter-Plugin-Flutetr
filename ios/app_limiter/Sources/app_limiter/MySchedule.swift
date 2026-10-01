import Foundation
import DeviceActivity

// DeviceActivity schedules only take effect when the host app ships a
// DeviceActivityMonitor extension that reacts to the interval/threshold events.

@available(iOS 15.0, *)
extension DeviceActivityName {
    static let daily = Self("daily")
}

@available(iOS 15.0, *)
extension DeviceActivityEvent.Name {
    static let encouraged = Self("encouraged")
}

@available(iOS 15.0, *)
class MySchedule {
    private static var startHour = 15
    private static var startMinute = 8
    private static var endHour = 16
    private static var endMinute = 8
    private static var repeats = false
    private static var thresholdMinutes = 1

    static public func configure(schedulePayload: [String: Any]?) {
        guard let schedulePayload else {
            return
        }

        if let value = schedulePayload["startHour"] as? Int {
            startHour = min(max(value, 0), 23)
        }
        if let value = schedulePayload["startMinute"] as? Int {
            startMinute = min(max(value, 0), 59)
        }
        if let value = schedulePayload["endHour"] as? Int {
            endHour = min(max(value, 0), 23)
        }
        if let value = schedulePayload["endMinute"] as? Int {
            endMinute = min(max(value, 0), 59)
        }
        if let value = schedulePayload["repeats"] as? Bool {
            repeats = value
        }
        if let value = schedulePayload["thresholdMinutes"] as? Int {
            thresholdMinutes = max(value, 1)
        }

        NotificationCenter.default.post(
            name: .appLimiterScheduleConfigured,
            object: nil,
            userInfo: [
                "startHour": startHour,
                "startMinute": startMinute,
                "endHour": endHour,
                "endMinute": endMinute,
                "repeats": repeats,
                "thresholdMinutes": thresholdMinutes,
                "phase": "configured",
            ]
        )
    }

    private static var schedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: startMinute),
            intervalEnd: DateComponents(hour: endHour, minute: endMinute),
            repeats: repeats,
            warningTime: nil
        )
    }

    static public func unsetSchedule() {
        let center = DeviceActivityCenter()
        if center.activities.isEmpty {
            return
        }
        center.stopMonitoring(center.activities)
    }

    static public func setSchedule() {
        let applications = MyModel.shared.selectionToEncourage
        if applications.applicationTokens.isEmpty {
            print("empty applicationTokens")
        }
        if applications.categoryTokens.isEmpty {
            print("empty categoryTokens")
        }

        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .encouraged: DeviceActivityEvent(
                applications: applications.applicationTokens,
                categories: applications.categoryTokens,
                threshold: DateComponents(minute: thresholdMinutes)
            )
        ]

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
            NotificationCenter.default.post(
                name: .appLimiterScheduleConfigured,
                object: nil,
                userInfo: [
                    "startHour": startHour,
                    "startMinute": startMinute,
                    "endHour": endHour,
                    "endMinute": endMinute,
                    "repeats": repeats,
                    "thresholdMinutes": thresholdMinutes,
                    "phase": "monitoring_started",
                ]
            )
        } catch {
            print("Error monitoring schedule: ", error)
            NotificationCenter.default.post(
                name: .appLimiterScheduleConfigured,
                object: nil,
                userInfo: [
                    "phase": "error",
                    "message": error.localizedDescription,
                ]
            )
        }
    }
}
