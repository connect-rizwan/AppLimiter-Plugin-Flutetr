import Foundation
import FamilyControls
import ManagedSettings

@available(iOS 15.0, *)
private let _MyModel = MyModel()

@available(iOS 15.0, *)
class MyModel: ObservableObject {
    let store = ManagedSettingsStore()

    @Published var selectionToDiscourage: FamilyActivitySelection
    @Published var selectionToEncourage: FamilyActivitySelection
    @Published var selectedApps = FamilyActivitySelection()

    init() {
        selectionToDiscourage = FamilyActivitySelection()
        selectionToEncourage = FamilyActivitySelection()
    }

    class var shared: MyModel {
        return _MyModel
    }

    /// WARNING: Using this method together with blockApps() will cause conflicts
    /// as they both modify the same ManagedSettingsStore instance
    func setShieldRestrictions() {
        print("setShieldRestrictions")
        let applications = MyModel.shared.selectionToDiscourage

        if applications.applicationTokens.isEmpty {
            print("empty applicationTokens")
        }
        if applications.categoryTokens.isEmpty {
            print("empty categoryTokens")
        }

        store.shield.applications = applications.applicationTokens.isEmpty ? nil : applications.applicationTokens
        store.shield.applicationCategories = applications.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(applications.categoryTokens)
    }

    func blockApps() {
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else {
            return
        }

        if !selectedApps.applicationTokens.isEmpty {
            store.shield.applications = selectedApps.applicationTokens
        }

        if !selectedApps.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selectedApps.categoryTokens)
        }
    }

    func unblockApps() {
        store.clearAllSettings()
    }

    func isAppsBlocked() -> Bool {
        let hasApplications = store.shield.applications != nil && !store.shield.applications!.isEmpty

        let hasCategories: Bool
        if let categories = store.shield.applicationCategories {
            switch categories {
            case .all:
                hasCategories = true
            case .specific(let categoryTokens, except: _):
                hasCategories = !categoryTokens.isEmpty
            @unknown default:
                hasCategories = false
            }
        } else {
            hasCategories = false
        }

        let isBlocked = hasApplications || hasCategories
        return isBlocked
    }
}
