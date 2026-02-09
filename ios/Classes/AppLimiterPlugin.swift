import Flutter
import UIKit
import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

/// Global variable to store the current method being called
/// Used for communication between different UI components
var globalMethodCall = ""

/// AppLimiterPlugin: Main plugin class that handles the communication between Flutter and iOS
/// Implements FlutterPlugin protocol to handle method channel calls
/// This plugin provides functionality for:
/// - Getting platform version
/// - Blocking/unblocking apps using Screen Time API
/// - Handling permissions for Screen Time functionality
public class AppLimiterPlugin: NSObject, FlutterPlugin {
    /// Registers the plugin with the Flutter engine
    /// Sets up the method channel for communication
    /// - Parameter registrar: The plugin registrar used to set up the channel
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_limiter", binaryMessenger: registrar.messenger())
        let instance = AppLimiterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Handles method calls from Flutter
    /// Supported methods:
    /// - getPlatformVersion: Returns the current iOS version
    /// - blockApp: Initiates the app blocking process (iOS 16+ only)
    /// - requestPermission: Requests Screen Time permissions (iOS 16+ only)
    /// - showAppPicker: Shows app picker for selecting apps to block (iOS 15+ only)
    /// - blockIOSApps: Blocks the selected apps (iOS 15+ only)
    /// - unblockIOSApps: Unblocks all apps (iOS 15+ only)
    /// - isIOSAppsBlocked: Checks if apps are currently blocked (iOS 15+ only)
    /// - getAuthorizationStatus: Gets current authorization status (iOS 16+ only)
    /// - Parameter call: The method call from Flutter
    /// - Parameter result: The callback to send the result back to Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "blockApp":
            if #available(iOS 16.0, *) {
                handleAppSelection(method: "selectAppsToDiscourage", result: result)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }
        
        case "requestPermission":
        if #available(iOS 16.0, *) {
            requestPermission(result: result)
        }else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }

        case "showAppPicker":
            if #available(iOS 16.0, *) {
                showAppPicker(result: result)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }

        case "blockIOSApps":
            if #available(iOS 16.0, *) {
                blockIOSApps(result: result)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }

        case "unblockIOSApps":
            if #available(iOS 16.0, *) {
                unblockIOSApps(result: result)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }

        case "isIOSAppsBlocked":
            if #available(iOS 16.0, *) {
                isIOSAppsBlocked(result: result)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }

        case "getAuthorizationStatus":
            if #available(iOS 16.0, *) {
                getAuthorizationStatus(result: result)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16+ required", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.0, *)
    private func handleAppSelection(method: String, result: @escaping FlutterResult) {
        let status = AuthorizationCenter.shared.authorizationStatus

        if status == .approved {
            presentContentView(method: method)
            result(nil)
        } else {
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    let newStatus = AuthorizationCenter.shared.authorizationStatus
                    if newStatus == .approved {
                        presentContentView(method: method)
                        result(nil)
                    } else {
                        result(FlutterError(code: "PERMISSION_DENIED", message: "User denied permission", details: nil))
                    }
                } catch {
                    result(FlutterError(code: "AUTH_ERROR", message: "Failed to request authorization", details: error.localizedDescription))
                }
            }
        }
    }

    // New method to request permission separately
    @available(iOS 16.0, *)
    private func requestPermission(result: @escaping FlutterResult) {
        let status = AuthorizationCenter.shared.authorizationStatus

        if status == .approved {
            result(true) // Permission already granted
        } else {
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    let newStatus = AuthorizationCenter.shared.authorizationStatus
                    if newStatus == .approved {
                        result(true) // Permission granted
                    } else {
                        result(FlutterError(code: "PERMISSION_DENIED", message: "User denied permission", details: nil))
                    }
                } catch {
                    result(FlutterError(code: "AUTH_ERROR", message: "Failed to request authorization", details: error.localizedDescription))
                }
            }
        }
    }

    private func presentContentView(method: String) {
        if #available(iOS 13.0, *) {
            // Get root view controller using modern API
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }

            guard let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                // Fallback: try to get any root view controller
                guard let fallbackVC = windowScene.windows.first?.rootViewController else {
                    return
                }
                presentViewController(method: method, from: fallbackVC)
                return
            }

            globalMethodCall = method
            presentViewController(method: method, from: rootVC)
        }
    }

    private func presentViewController(method: String, from rootVC: UIViewController) {
        DispatchQueue.main.async {
            if #available(iOS 15.0, *) {
                let vc = UIHostingController(
                    rootView: ContentView()
                        .environmentObject(MyModel.shared)
                        .environmentObject(ManagedSettingsStore())
                )
                rootVC.present(vc, animated: true)
            } else {
                let vc = UIViewController()
                rootVC.present(vc, animated: true)
            }
        }
    }

    /// Shows app picker UI for selecting apps to block
    @available(iOS 16.0, *)
    private func showAppPicker(result: @escaping FlutterResult) {
        let status = AuthorizationCenter.shared.authorizationStatus

        if status == .approved {
            presentContentView(method: "selectAppsForBlocking")
            result(nil)
        } else {
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    let newStatus = AuthorizationCenter.shared.authorizationStatus

                    if newStatus == .approved {
                        presentContentView(method: "selectAppsForBlocking")
                        result(nil)
                    } else {
                        result(FlutterError(code: "PERMISSION_DENIED", message: "User denied permission", details: nil))
                    }
                } catch {
                    result(FlutterError(code: "AUTH_ERROR", message: "Failed to request authorization", details: error.localizedDescription))
                }
            }
        }
    }

    /// Blocks the selected apps
    @available(iOS 16.0, *)
    private func blockIOSApps(result: @escaping FlutterResult) {
        MyModel.shared.blockApps()
        result(nil)
    }

    /// Unblocks all apps
    @available(iOS 16.0, *)
    private func unblockIOSApps(result: @escaping FlutterResult) {
        MyModel.shared.unblockApps()
        result(nil)
    }

    /// Checks if apps are currently blocked
    @available(iOS 16.0, *)
    private func isIOSAppsBlocked(result: @escaping FlutterResult) {
        let isBlocked = MyModel.shared.isAppsBlocked()
        result(isBlocked)
    }

    @available(iOS 16.0, *)
    private func getAuthorizationStatus(result: @escaping FlutterResult) {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .notDetermined:
            result("notDetermined")
        case .approved:
            result("authorized")
        case .denied:
            result("denied")
        @unknown default:
            result("notDetermined")
        }
    }
}
