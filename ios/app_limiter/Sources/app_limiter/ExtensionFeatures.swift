import DeviceActivity
import FamilyControls
import Flutter
import Foundation
import ManagedSettings

/// Features that rely on app extensions in the host app: a custom shield,
/// timed blocks and schedules. See ios/extension_templates/README.md.
@available(iOS 16.0, *)
enum ExtensionFeatures {
    static let shieldExtensionPoint = "com.apple.ManagedSettingsUI.shield-configuration-service"
    static let monitorExtensionPoint = "com.apple.deviceactivity.monitor-extension"

    /// Apple rejects DeviceActivity intervals shorter than 15 minutes.
    static let minimumIntervalMinutes = 15

    static func installedExtensionPoints() -> Set<String> {
        guard
            let url = Bundle.main.builtInPlugInsURL,
            let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        else { return [] }
        return Set(items.filter { $0.pathExtension == "appex" }.compactMap { item in
            let info = Bundle(url: item)?.object(forInfoDictionaryKey: "NSExtension") as? [String: Any]
            return info?["NSExtensionPointIdentifier"] as? String
        })
    }

    static func status() -> [String: Any?] {
        let points = installedExtensionPoints()
        return [
            "appGroup": AppLimiterShared.appGroup,
            "appGroupAccessible": AppLimiterShared.defaults != nil,
            "shieldConfigurationExtension": points.contains(shieldExtensionPoint),
            "deviceActivityMonitorExtension": points.contains(monitorExtensionPoint),
        ]
    }

    /// Returns an EXTENSION_MISSING error when the App Group or [extensionPoint] is missing.
    static func requirement(_ extensionPoint: String, name: String) -> FlutterError? {
        guard AppLimiterShared.defaults != nil else {
            return FlutterError(
                code: "EXTENSION_MISSING",
                message: "Set the AppLimiterAppGroup Info.plist key to an App Group shared with your extensions.",
                details: nil
            )
        }
        guard installedExtensionPoints().contains(extensionPoint) else {
            return FlutterError(
                code: "EXTENSION_MISSING",
                message: "Add the \(name) extension from ios/extension_templates to your app.",
                details: nil
            )
        }
        return nil
    }

    // MARK: Shield

    static func setShield(_ args: [String: Any]?) -> FlutterError? {
        if let error = requirement(shieldExtensionPoint, name: "Shield Configuration") { return error }
        guard let args, args.values.contains(where: { !($0 is NSNull) }) else {
            AppLimiterShared.saveShield(nil)
            return nil
        }
        func color(_ key: String) -> UInt32? { (args[key] as? NSNumber).map { UInt32(truncatingIfNeeded: $0.int64Value) } }
        func string(_ key: String) -> String? { (args[key] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        AppLimiterShared.saveShield(AppLimiterShared.ShieldConfig(
            title: string("title"),
            subtitle: string("subtitle"),
            primaryButtonLabel: string("primaryButtonLabel"),
            secondaryButtonLabel: string("secondaryButtonLabel"),
            backgroundColor: color("backgroundColor"),
            titleColor: color("titleColor"),
            subtitleColor: color("subtitleColor"),
            primaryButtonBackgroundColor: color("primaryButtonBackgroundColor"),
            primaryButtonLabelColor: color("primaryButtonLabelColor"),
            icon: (args["icon"] as? FlutterStandardTypedData)?.data
        ))
        return nil
    }

    // MARK: Timed block

    /// Shields the selection now and ends it after [durationMs] via the monitor extension.
    static func startTimedBlock(durationMs: Int) -> FlutterError? {
        if let error = requirement(monitorExtensionPoint, name: "Device Activity Monitor") { return error }
        guard durationMs >= minimumIntervalMinutes * 60 * 1000 else {
            return FlutterError(
                code: "INVALID_ARGUMENT",
                message: "iOS timed blocks must last at least \(minimumIntervalMinutes) minutes.",
                details: nil
            )
        }

        let now = Date()
        let end = now.addingTimeInterval(Double(durationMs) / 1000)
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(components, from: now),
            intervalEnd: Calendar.current.dateComponents(components, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([AppLimiterShared.timedActivity])
        do {
            try center.startMonitoring(AppLimiterShared.timedActivity, during: schedule)
        } catch {
            return monitoringError(error)
        }
        AppLimiterShared.timedBlockUntil = end
        return nil
    }

    static func cancelTimedBlock() {
        DeviceActivityCenter().stopMonitoring([AppLimiterShared.timedActivity])
        AppLimiterShared.timedBlockUntil = nil
    }

    // MARK: Schedules

    static func setSchedule(_ args: [String: Any]?, selection: FamilyActivitySelection) -> FlutterError? {
        if let error = requirement(monitorExtensionPoint, name: "Device Activity Monitor") { return error }
        guard
            let args,
            let id = (args["id"] as? String).flatMap({ $0.isEmpty ? nil : $0 }),
            let start = args["startMinute"] as? Int, (0..<1440).contains(start),
            let end = args["endMinute"] as? Int, (0..<1440).contains(end)
        else {
            return FlutterError(code: "INVALID_ARGUMENT", message: "Invalid schedule.", details: nil)
        }
        let weekdays = ((args["weekdays"] as? [Int]) ?? Array(1...7)).filter { (1...7).contains($0) }
        guard !weekdays.isEmpty else {
            return FlutterError(code: "INVALID_ARGUMENT", message: "weekdays must not be empty.", details: nil)
        }

        let schedule = AppLimiterShared.Schedule(
            id: id,
            startMinute: start,
            endMinute: end,
            weekdays: weekdays,
            selection: selection
        )

        // Save first: the extension reads the schedule when monitoring starts.
        var schedules = AppLimiterShared.loadSchedules()
        let previous = schedules[id]
        schedules[id] = schedule
        AppLimiterShared.saveSchedules(schedules)

        stopMonitoring(id)
        do {
            try startMonitoring(schedule)
        } catch {
            stopMonitoring(id)
            schedules[id] = previous
            AppLimiterShared.saveSchedules(schedules)
            if let previous { try? startMonitoring(previous) }
            return monitoringError(error)
        }

        // Apply right away when the window is already open.
        let store = AppLimiterShared.scheduleStore(id)
        if isActive(schedule, at: Date()) {
            AppLimiterShared.applyShield(selection, to: store)
        } else {
            AppLimiterShared.clearShield(store)
        }
        return nil
    }

    static func removeSchedule(_ id: String) {
        stopMonitoring(id)
        AppLimiterShared.clearShield(AppLimiterShared.scheduleStore(id))
        var schedules = AppLimiterShared.loadSchedules()
        schedules[id] = nil
        AppLimiterShared.saveSchedules(schedules)
    }

    static func schedules() -> [[String: Any]] {
        AppLimiterShared.loadSchedules().values.sorted { $0.id < $1.id }.map {
            [
                "id": $0.id,
                "startMinute": $0.startMinute,
                "endMinute": $0.endMinute,
                "weekdays": $0.weekdays.sorted(),
                "applicationCount": $0.selection.applicationTokens.count,
                "categoryCount": $0.selection.categoryTokens.count,
                "webDomainCount": $0.selection.webDomainTokens.count,
            ]
        }
    }

    static func activeScheduleIds() -> [String] {
        AppLimiterShared.loadSchedules().keys
            .filter { AppLimiterShared.isShielding(AppLimiterShared.scheduleStore($0)) }
            .sorted()
    }

    static func timedBlockUntil() -> Date? {
        guard let until = AppLimiterShared.timedBlockUntil, until > Date() else { return nil }
        return until
    }

    /// Same rules as the Dart and Android implementations.
    static func isActive(_ schedule: AppLimiterShared.Schedule, at date: Date) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let day = AppLimiterShared.isoWeekday(date)
        let previousDay = day == 1 ? 7 : day - 1
        let days = Set(schedule.weekdays)
        if schedule.startMinute == schedule.endMinute { return days.contains(day) }
        if schedule.startMinute < schedule.endMinute {
            return days.contains(day) && minute >= schedule.startMinute && minute < schedule.endMinute
        }
        return (days.contains(day) && minute >= schedule.startMinute)
            || (days.contains(previousDay) && minute < schedule.endMinute)
    }

    private static func time(_ minute: Int) -> DateComponents {
        DateComponents(hour: minute / 60, minute: minute % 60)
    }

    /// Overnight windows become an evening part and a morning part, so the
    /// weekday check in the extension refers to the right day.
    private static func startMonitoring(_ schedule: AppLimiterShared.Schedule) throws {
        let center = DeviceActivityCenter()
        let lastMinute = 23 * 60 + 59
        func monitor(_ part: String, _ start: Int, _ end: Int) throws {
            try center.startMonitoring(
                AppLimiterShared.scheduleActivity(schedule.id, part: part),
                during: DeviceActivitySchedule(intervalStart: time(start), intervalEnd: time(end), repeats: true)
            )
        }

        if schedule.startMinute == schedule.endMinute {
            try monitor("a", 0, lastMinute)
        } else if schedule.isOvernight {
            try monitor("a", schedule.startMinute, lastMinute)
            if schedule.endMinute > 0 {
                try monitor("b", 0, schedule.endMinute)
            }
        } else {
            try monitor("a", schedule.startMinute, schedule.endMinute)
        }
    }

    private static func stopMonitoring(_ id: String) {
        DeviceActivityCenter().stopMonitoring([
            AppLimiterShared.scheduleActivity(id, part: "a"),
            AppLimiterShared.scheduleActivity(id, part: "b"),
        ])
    }

    private static func monitoringError(_ error: Error) -> FlutterError {
        if let error = error as? DeviceActivityCenter.MonitoringError {
            switch error {
            case .intervalTooShort:
                return FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Each iOS block window must last at least \(minimumIntervalMinutes) minutes.",
                    details: nil
                )
            case .excessiveActivities:
                return FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Too many iOS schedules. Remove some first.",
                    details: nil
                )
            case .unauthorized:
                return FlutterError(code: "PERMISSION_DENIED", message: "Screen Time access has not been granted.", details: nil)
            default:
                break
            }
        }
        return FlutterError(code: "UNKNOWN", message: "Device activity monitoring failed.", details: error.localizedDescription)
    }
}
