// Shield Configuration extension for app_limiter.
//
// Draws the iOS block screen from the configuration set with
// `AppLimiter().ios.setShield(...)`. Copy this file and AppLimiterShared.swift
// into a "Shield Configuration Extension" target. See
// ios/extension_templates/README.md.

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain ?? category.localizedDisplayName)
    }

    /// Unset fields fall back to Apple's default shield.
    private func makeConfiguration(name: String?) -> ShieldConfiguration {
        guard let config = AppLimiterShared.loadShield() else {
            return ShieldConfiguration()
        }

        func text(_ value: String?) -> String? {
            value?.replacingOccurrences(of: "{app}", with: name ?? "This app")
        }

        func label(_ value: String?, _ color: UInt32?) -> ShieldConfiguration.Label? {
            guard let value = text(value) else { return nil }
            return ShieldConfiguration.Label(text: value, color: uiColor(color) ?? .label)
        }

        return ShieldConfiguration(
            backgroundBlurStyle: config.backgroundColor == nil ? nil : .systemMaterial,
            backgroundColor: uiColor(config.backgroundColor),
            icon: config.icon.flatMap { UIImage(data: $0) },
            title: label(config.title, config.titleColor),
            subtitle: label(config.subtitle, config.subtitleColor),
            primaryButtonLabel: label(config.primaryButtonLabel, config.primaryButtonLabelColor),
            primaryButtonBackgroundColor: uiColor(config.primaryButtonBackgroundColor),
            secondaryButtonLabel: label(config.secondaryButtonLabel, config.primaryButtonBackgroundColor)
        )
    }

    private func uiColor(_ argb: UInt32?) -> UIColor? {
        guard let argb else { return nil }
        return UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
    }
}
