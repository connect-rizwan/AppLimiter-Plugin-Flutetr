import Flutter
import UIKit
import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

extension Notification.Name {
    static let appLimiterSelectionUpdated = Notification.Name("app_limiter_selection_updated")
    static let appLimiterScheduleConfigured = Notification.Name("app_limiter_schedule_configured")
    static let appLimiterBlockingStateChanged = Notification.Name("app_limiter_blocking_state_changed")
}

/// AppLimiterPlugin: Main plugin class that handles the communication between Flutter and iOS
/// Implements FlutterPlugin protocol to handle method channel calls
/// This plugin provides functionality for:
/// - Getting platform version
/// - Blocking/unblocking apps using Screen Time API
/// - Handling permissions for Screen Time functionality
public class AppLimiterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    /// Registers the plugin with the Flutter engine
    /// Sets up the method channel for communication
    /// - Parameter registrar: The plugin registrar used to set up the channel
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_limiter", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "app_limiter/events", binaryMessenger: registrar.messenger())
        let instance = AppLimiterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleSelectionUpdatedNotification(_:)),
            name: .appLimiterSelectionUpdated,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleScheduleConfiguredNotification(_:)),
            name: .appLimiterScheduleConfigured,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleBlockingStateChangedNotification(_:)),
            name: .appLimiterBlockingStateChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func emitEvent(name: String, payload: [String: Any] = [:]) {
        let event: [String: Any] = [
            "name": name,
            "payload": payload,
            "timestamp": Int(Date().timeIntervalSince1970),
        ]
        if Thread.isMainThread {
            eventSink?(event)
        } else {
            DispatchQueue.main.async { [weak self] in self?.eventSink?(event) }
        }
    }

    private static func payload(from notification: Notification) -> [String: Any] {
        var payload: [String: Any] = [:]
        notification.userInfo?.forEach { key, value in
            payload[String(describing: key)] = value
        }
        return payload
    }

    @objc
    private func handleSelectionUpdatedNotification(_ notification: Notification) {
        emitEvent(name: "ios_selection_updated", payload: Self.payload(from: notification))
    }

    @objc
    private func handleScheduleConfiguredNotification(_ notification: Notification) {
        emitEvent(name: "ios_schedule_configured", payload: Self.payload(from: notification))
    }

    @objc
    private func handleBlockingStateChangedNotification(_ notification: Notification) {
        emitEvent(name: "ios_blocking_state_changed", payload: Self.payload(from: notification))
    }

    /// Handles method calls from Flutter
    /// Supported methods:
    /// - getPlatformVersion: Returns the current iOS version
    /// - selectAndConfigureIosAppRestrictions / blockApp: Picker that shields the selection on Done
    /// - showAppPicker: Picker that only saves the selection
    /// - blockIOSApps / unblockIOSApps / isIOSAppsBlocked: Shield control for the saved selection
    /// - getAuthorizationStatus / requestPermission: Screen Time authorization
    /// - configureIosSchedule: DeviceActivity schedule
    /// - getCapabilities: Platform and state summary
    /// - Parameter call: The method call from Flutter
    /// - Parameter result: The callback to send the result back to Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPlatformVersion" {
            result("iOS " + UIDevice.current.systemVersion)
            return
        }

        guard #available(iOS 16.0, *) else {
            if call.method == "getCapabilities" {
                result(["platform": "ios", "screenTimeSupported": false])
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }
            return
        }

        let arguments = call.arguments as? [String: Any]

        switch call.method {
        case "selectAndConfigureIosAppRestrictions", "blockApp":
            MySchedule.configure(schedulePayload: arguments?["schedule"] as? [String: Any])
            withAuthorization(result: result) { [weak self] in
                self?.presentPicker(result: result) { selection in
                    if let selection {
                        MyModel.shared.updateDiscourageSelection(selection)
                        MyModel.shared.setShieldRestrictions()
                    }
                    result(nil)
                }
            }

        case "showAppPicker":
            withAuthorization(result: result) { [weak self] in
                self?.presentPicker(result: result) { selection in
                    if let selection {
                        MyModel.shared.updateDiscourageSelection(selection)
                        result(true)
                    } else {
                        result(false)
                    }
                }
            }

        case "blockIOSApps":
            guard AuthorizationCenter.shared.authorizationStatus == .approved else {
                result(FlutterError(
                    code: "PERMISSION_DENIED",
                    message: "Screen Time access has not been granted. Call requestIosPermission() first.",
                    details: nil
                ))
                return
            }
            guard MyModel.shared.hasDiscourageSelection else {
                result(FlutterError(
                    code: "NO_SELECTION",
                    message: "No apps selected. Call showIOSAppPicker() first.",
                    details: nil
                ))
                return
            }
            MyModel.shared.setShieldRestrictions()
            result(nil)

        case "unblockIOSApps":
            MyModel.shared.clearShieldRestrictions()
            result(nil)

        case "isIOSAppsBlocked":
            result(MyModel.shared.isShieldActive)

        case "getAuthorizationStatus":
            result(authorizationStatusString())

        case "configureIosSchedule":
            MySchedule.configure(schedulePayload: arguments?["schedule"] as? [String: Any])
            MySchedule.setSchedule()
            result(nil)

        case "requestPermission":
            requestPermission(result: result)

        case "getCapabilities":
            let selection = MyModel.shared.selectionToDiscourage
            result([
                "platform": "ios",
                "screenTimeSupported": true,
                "authorizationStatus": authorizationStatusString(),
                "blockingActive": MyModel.shared.isShieldActive,
                "selectedApplicationCount": selection.applicationTokens.count,
                "selectedCategoryCount": selection.categoryTokens.count,
                "selectedWebDomainCount": selection.webDomainTokens.count,
            ])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.0, *)
    private func authorizationStatusString() -> String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            return "approved"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "notDetermined"
        }
    }

    /// Runs [onApproved] on the main actor once Screen Time access is approved,
    /// requesting it first if needed; otherwise completes [result] with an error.
    @available(iOS 16.0, *)
    private func withAuthorization(result: @escaping FlutterResult, onApproved: @escaping () -> Void) {
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            onApproved()
            return
        }

        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                if AuthorizationCenter.shared.authorizationStatus == .approved {
                    onApproved()
                } else {
                    result(FlutterError(code: "PERMISSION_DENIED", message: "User denied permission", details: nil))
                }
            } catch {
                result(FlutterError(code: "AUTH_ERROR", message: "Failed to request authorization", details: error.localizedDescription))
            }
        }
    }

    /// Completes with true if approved and false if the user declined.
    /// Other failures (restricted device, unsupported account, ...) are reported as errors.
    @available(iOS 16.0, *)
    private func requestPermission(result: @escaping FlutterResult) {
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            emitEvent(name: "ios_permission_status", payload: ["status": "approved"])
            result(true)
            return
        }

        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                let approved = AuthorizationCenter.shared.authorizationStatus == .approved
                emitEvent(name: "ios_permission_status", payload: ["status": approved ? "approved" : "denied"])
                result(approved)
            } catch FamilyControlsError.authorizationCanceled {
                emitEvent(name: "ios_permission_status", payload: ["status": "denied"])
                result(false)
            } catch {
                emitEvent(
                    name: "ios_permission_status",
                    payload: ["status": "error", "message": error.localizedDescription]
                )
                result(FlutterError(code: "AUTH_ERROR", message: "Failed to request authorization", details: error.localizedDescription))
            }
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    /// Topmost view controller of the foreground scene. Works for both
    /// UIScene-based apps (where `delegate.window` is nil) and legacy apps.
    private func topViewController() -> UIViewController? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScenes = windowScenes.filter { $0.activationState == .foregroundActive }
        let windows = (activeScenes.isEmpty ? windowScenes : activeScenes).flatMap { $0.windows }

        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
            ?? UIApplication.shared.delegate?.window??.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Presents the picker and calls [completion] exactly once after it is
    /// dismissed, with the confirmed selection or nil if cancelled.
    @available(iOS 16.0, *)
    private func presentPicker(
        result: @escaping FlutterResult,
        completion: @escaping (FamilyActivitySelection?) -> Void
    ) {
        guard let presenter = topViewController() else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Unable to find a view controller to present the picker.", details: nil))
            return
        }

        weak var hostRef: UIViewController?
        var finished = false
        let view = ContentView(initialSelection: MyModel.shared.selectionToDiscourage) { selection in
            guard !finished else { return }
            finished = true
            guard let host = hostRef else {
                completion(selection)
                return
            }
            host.dismiss(animated: true) { completion(selection) }
        }

        let host = UIHostingController(rootView: view)
        // Force Cancel/Done so the pending Flutter call always completes.
        host.isModalInPresentation = true
        hostRef = host
        presenter.present(host, animated: true)
        emitEvent(name: "ios_picker_presented")
    }
}
