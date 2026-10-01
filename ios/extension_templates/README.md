# app_limiter iOS extensions

Apple only lets app extensions inside your app customize the block screen
(shield) and start or end blocks while your app is closed. These templates add
that to your app:

| Extension | Needed for |
| --- | --- |
| `AppLimiterShield` (Shield Configuration) | `ios.setShield(...)` |
| `AppLimiterMonitor` (Device Activity Monitor) | `ios.blockSelectedApps(duration: ...)`, `ios.setSchedule(...)` |

The plugin and the extensions share data through an App Group.

## Automatic setup

From your Flutter app's root directory:

```sh
dart run app_limiter:setup_ios --app-group group.com.your.app
```

This needs Ruby and the `xcodeproj` gem (installed with CocoaPods). It:

1. creates `ios/AppLimiterShield` and `ios/AppLimiterMonitor` from these templates
   and adds them as extension targets embedded in Runner,
2. gives Runner and both extensions the Family Controls and App Groups
   entitlements,
3. sets the `AppLimiterAppGroup` Info.plist key in all three.

Then open `ios/Runner.xcworkspace` in Xcode once, select your team for the two
new targets if needed, and let automatic signing register the App Group and the
extension bundle IDs. Run the command again after updating app_limiter to
refresh the extension sources.

## Manual setup

1. In Xcode, File > New > Target: add a **Shield Configuration Extension** and a
   **Device Activity Monitor Extension** (iOS 16 deployment target).
2. Replace their generated Swift files with
   `ShieldConfiguration/ShieldConfigurationExtension.swift` and
   `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift`, and add
   `AppLimiterShared.swift` to both targets. Set each `NSExtensionPrincipalClass`
   to `$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension` /
   `$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`.
3. Add the **Family Controls** and **App Groups** capabilities to Runner and to
   both extensions, using the same App Group.
4. Add a String `AppLimiterAppGroup` key with the App Group to the Info.plist of
   Runner and of both extensions.

## Checking the setup

```dart
final status = await AppLimiter().ios.getExtensionStatus();
// appGroup, appGroupAccessible, hasShieldConfigurationExtension,
// hasDeviceActivityMonitorExtension
```

Features whose extension is missing throw `AppLimiterException` with
`AppLimiterErrorCode.extensionMissing`.

## Apple limits

- Timed blocks and each part of a schedule window must last at least 15 minutes.
  Overnight windows are split at midnight into two parts.
- An app can monitor up to 20 device activities; each schedule uses one, or two
  when it runs overnight, and a timed block uses one.
- Distributing the app needs the Family Controls (Distribution) entitlement for
  the app and both extensions, requested from Apple.
- The primary shield button always closes the blocked app. Reacting to the
  secondary button needs your own Shield Action extension.
