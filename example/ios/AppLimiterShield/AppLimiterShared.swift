// AppLimiterShared.swift
//
// Shared between the app_limiter plugin and the app extensions in
// ios/extension_templates. The copies must stay identical; a test in
// test/ios_templates_test.dart checks that.

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// State shared through the App Group container named by the
/// `AppLimiterAppGroup` Info.plist key (set in the app and in each extension).
@available(iOS 16.0, *)
enum AppLimiterShared {
    static let appGroupInfoKey = "AppLimiterAppGroup"

    static var appGroup: String? {
        (Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    static var defaults: UserDefaults? {
        appGroup.flatMap { UserDefaults(suiteName: $0) }
    }

    // MARK: Device activity names

    static let timedActivity = DeviceActivityName("app_limiter.timed")
    private static let schedulePrefix = "app_limiter.schedule."

    /// Overnight windows are split in two activities: the evening part ("a")
    /// and the morning part ("b"). Other windows only use "a".
    static func scheduleActivity(_ id: String, part: String) -> DeviceActivityName {
        DeviceActivityName("\(schedulePrefix)\(part).\(id)")
    }

    /// Returns the schedule id and part ("a" or "b") of a schedule activity.
    static func scheduleInfo(from activity: DeviceActivityName) -> (id: String, part: String)? {
        let name = activity.rawValue
        guard name.hasPrefix(schedulePrefix) else { return nil }
        let rest = name.dropFirst(schedulePrefix.count)
        guard rest.count > 2, rest.dropFirst().first == "." else { return nil }
        return (String(rest.dropFirst(2)), String(rest.prefix(1)))
    }

    static func scheduleStore(_ id: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name("\(schedulePrefix)\(id)"))
    }

    // MARK: Shield configuration

    struct ShieldConfig: Codable {
        var title: String?
        var subtitle: String?
        var primaryButtonLabel: String?
        var secondaryButtonLabel: String?
        /// ARGB colors.
        var backgroundColor: UInt32?
        var titleColor: UInt32?
        var subtitleColor: UInt32?
        var primaryButtonBackgroundColor: UInt32?
        var primaryButtonLabelColor: UInt32?
        /// PNG or JPEG bytes.
        var icon: Data?
    }

    private static let shieldKey = "app_limiter.shield"

    static func loadShield() -> ShieldConfig? {
        guard let data = defaults?.data(forKey: shieldKey) else { return nil }
        return try? JSONDecoder().decode(ShieldConfig.self, from: data)
    }

    static func saveShield(_ config: ShieldConfig?) {
        guard let defaults else { return }
        if let config, let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: shieldKey)
        } else {
            defaults.removeObject(forKey: shieldKey)
        }
    }

    // MARK: Schedules

    struct Schedule: Codable {
        var id: String
        var startMinute: Int
        var endMinute: Int
        /// ISO weekdays, 1 = Monday ... 7 = Sunday.
        var weekdays: [Int]
        var selection: FamilyActivitySelection

        var isOvernight: Bool { endMinute < startMinute }
    }

    private static let schedulesKey = "app_limiter.schedules"

    static func loadSchedules() -> [String: Schedule] {
        guard
            let data = defaults?.data(forKey: schedulesKey),
            let schedules = try? JSONDecoder().decode([String: Schedule].self, from: data)
        else { return [:] }
        return schedules
    }

    static func saveSchedules(_ schedules: [String: Schedule]) {
        guard let defaults, let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: schedulesKey)
    }

    // MARK: Timed block

    private static let timedUntilKey = "app_limiter.timed_until"

    static var timedBlockUntil: Date? {
        get { defaults?.object(forKey: timedUntilKey) as? Date }
        set { defaults?.set(newValue, forKey: timedUntilKey) }
    }

    // MARK: Shields

    static func applyShield(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    static func clearShield(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    static func isShielding(_ store: ManagedSettingsStore) -> Bool {
        !(store.shield.applications?.isEmpty ?? true)
            || store.shield.applicationCategories != nil
            || !(store.shield.webDomains?.isEmpty ?? true)
    }

    /// ISO weekday (1 = Monday) of [date] in the current calendar.
    static func isoWeekday(_ date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date) // 1 = Sunday
        return weekday == 1 ? 7 : weekday - 1
    }
}
