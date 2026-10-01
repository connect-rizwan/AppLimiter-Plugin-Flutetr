import Foundation
import FamilyControls
import ManagedSettings

/// Holds the user's app/category selections and applies them as shields.
@available(iOS 15.0, *)
final class MyModel: ObservableObject {
    static let shared = MyModel()

    let store = ManagedSettingsStore()
    private static let discourageSelectionKey = "app_limiter_selection_discourage"
    private static let encourageSelectionKey = "app_limiter_selection_encourage"

    @Published var selectionToDiscourage: FamilyActivitySelection
    @Published var selectionToEncourage: FamilyActivitySelection

    init() {
        selectionToDiscourage = MyModel.loadSelection(for: MyModel.discourageSelectionKey)
        selectionToEncourage = MyModel.loadSelection(for: MyModel.encourageSelectionKey)
    }

    var hasDiscourageSelection: Bool {
        !selectionToDiscourage.applicationTokens.isEmpty
            || !selectionToDiscourage.categoryTokens.isEmpty
            || !selectionToDiscourage.webDomainTokens.isEmpty
    }

    /// True if any app, category or web domain is currently shielded.
    var isShieldActive: Bool {
        let hasApplications = !(store.shield.applications?.isEmpty ?? true)
        let hasCategories = store.shield.applicationCategories != nil
        let hasWebDomains = !(store.shield.webDomains?.isEmpty ?? true)
        return hasApplications || hasCategories || hasWebDomains
    }

    /// Saves a new selection without changing any shield.
    func updateDiscourageSelection(_ selection: FamilyActivitySelection) {
        selectionToDiscourage = selection
        Self.saveSelection(selection, for: Self.discourageSelectionKey)

        NotificationCenter.default.post(
            name: .appLimiterSelectionUpdated,
            object: nil,
            userInfo: [
                "selectionType": "discourage",
                "applicationCount": selection.applicationTokens.count,
                "categoryCount": selection.categoryTokens.count,
                "webDomainCount": selection.webDomainTokens.count,
            ]
        )
    }

    /// Shields everything in the saved discourage selection.
    func setShieldRestrictions() {
        let selection = selectionToDiscourage

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        postBlockingState()
    }

    /// Removes every shield set by this plugin. The saved selection is kept.
    func clearShieldRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil

        postBlockingState()
    }

    func saveEncourageSelection() {
        Self.saveSelection(selectionToEncourage, for: Self.encourageSelectionKey)

        NotificationCenter.default.post(
            name: .appLimiterSelectionUpdated,
            object: nil,
            userInfo: [
                "selectionType": "encourage",
                "applicationCount": selectionToEncourage.applicationTokens.count,
                "categoryCount": selectionToEncourage.categoryTokens.count,
            ]
        )
    }

    private func postBlockingState() {
        NotificationCenter.default.post(
            name: .appLimiterBlockingStateChanged,
            object: nil,
            userInfo: ["active": isShieldActive]
        )
    }

    private static func saveSelection(_ selection: FamilyActivitySelection, for key: String) {
        guard let encoded = try? JSONEncoder().encode(selection) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private static func loadSelection(for key: String) -> FamilyActivitySelection {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }

        return decoded
    }
}
