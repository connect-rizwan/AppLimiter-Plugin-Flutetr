# App Limiter Plugin

A Flutter plugin that allows developers to limit app usage and screen time on Android and iOS by blocking/unblocking apps and managing screen time permissions.

## 🧠 Features

- ✅ Block/unblock individual apps or every user app on Android
- ✅ Pick, block and unblock apps and categories on iOS (Screen Time API)
- ✅ Query blocking state and permission/authorization status
- ✅ Blocking survives reboots and app updates on Android
- ✅ Live event stream for blocking, selection and permission changes
- ✅ Optional Android enterprise (device owner) package suspension

### 🔧 Available Methods

```dart
// Common
Future<String?> getPlatformVersion()
Future<Map<String, dynamic>> getPlatformCapabilities()
Stream<Map<String, dynamic>> events

// Android
Future<bool> isAndroidPermissionAllowed()
Future<void> requestAndroidPermission()
Future<void> blockAndroidApp({required String packageName})
Future<void> unblockAndroidApp({required String packageName})
Future<void> blockAllAndroidApps()
Future<void> unblockAllAndroidApps()
Future<List<String>> getBlockedAndroidApps()
Future<bool> isAndroidBlockingActive()
Future<void> setAndroidEnterpriseModeEnabled({required bool enabled})
Future<bool> isAndroidEnterpriseModeEnabled()

// iOS
Future<bool> requestIosPermission()
Future<String> getIOSAuthorizationStatus() // notDetermined | denied | approved
Future<bool> showIOSAppPicker()            // selection only, true if confirmed
Future<void> blockIOSApps()                // shield the saved selection
Future<void> unblockIOSApps()
Future<bool> isIOSAppsBlocked()
Future<void> selectAndConfigureIosAppRestrictions({Map<String, dynamic>? schedule}) // pick + block in one step
Future<void> configureIosSchedule(Map<String, dynamic> schedule)
```

Android-only methods throw `MissingPluginException` on iOS and vice versa.

Deprecated compatibility methods still available:

```dart
blockAndUnblockIOSApp() // -> selectAndConfigureIosAppRestrictions()
blocAndroidApp()        // -> blockAllAndroidApps()
unblocAndroidApp()      // -> unblockAllAndroidApps()
```

### Errors

Failures are reported as `PlatformException` with these codes:

| Code | Meaning |
| --- | --- |
| `PERMISSION_DENIED` | Android overlay/usage access or iOS Screen Time access missing |
| `NO_SELECTION` | `blockIOSApps()` called before choosing apps |
| `INVALID_ARGUMENT` | Empty Android package name |
| `NO_VIEW_CONTROLLER` | iOS picker could not be presented |
| `ENTERPRISE_ACTION_FAILED` / `ENTERPRISE_NOT_AVAILABLE` | Device owner operations failed |

## 🪪 Setup

Minimum supported versions: Android 5.0 (API 21), iOS 16.0 for blocking (the pod builds on iOS 15).

### 🟢 Android

The plugin's manifest declares every permission, the foreground service (type
`specialUse`, required on Android 14+) and the receivers; nothing needs to be added
to your app's manifest.

At runtime, call `requestAndroidPermission()` until `isAndroidPermissionAllowed()`
returns true. Each call opens the settings screen for the next missing permission:
display over other apps, then usage access, then notifications (Android 13+).

Google Play notes:

- `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS` and the `specialUse` foreground
  service need a declaration in the Play Console explaining the app-blocking use.

Limitations:

- Settings, the permission controller and the package installer hide third-party
  overlays. When they are blocked, the user is sent to the home screen instead.
- The host app, the home launcher and System UI are never blocked.
- `blockAllAndroidApps()` blocks every app with a launcher icon, including
  preinstalled ones such as YouTube or Gmail, but keeps the phone dialer and
  Settings usable. Block Settings explicitly with `blockAndroidApp` if needed.

### 🟣 iOS

1. In Xcode, add the **Family Controls** capability to the Runner target. This
   adds `com.apple.developer.family-controls` to your `.entitlements` file
   (entitlements do not go in `Info.plist`).
2. Distribution builds need the Family Controls (Distribution) entitlement
   [requested from Apple](https://developer.apple.com/contact/request/family-controls-distribution).
3. Schedules set with `configureIosSchedule` only take effect if your app ships a
   `DeviceActivityMonitor` extension that applies shields on interval events.

Both Swift Package Manager and CocoaPods are supported.

## 📱 Platform Support

| Platform | Support |
| -------- | ------- |
| Android  | ✅      |
| iOS      | ✅      |
| Web      | ❌      |

## 🧪 Example Usage

```dart
final plugin = AppLimiter();

// Android
if (!await plugin.isAndroidPermissionAllowed()) {
  await plugin.requestAndroidPermission();
}
await plugin.blockAndroidApp(packageName: 'com.example.target');
await plugin.unblockAndroidApp(packageName: 'com.example.target');
await plugin.blockAllAndroidApps();
await plugin.unblockAllAndroidApps();

// Optional enterprise mode (requires Android device-owner setup)
final capabilities = await plugin.getPlatformCapabilities();
if (capabilities['enterpriseCapable'] == true) {
  await plugin.setAndroidEnterpriseModeEnabled(enabled: true);
}

// iOS
if (await plugin.requestIosPermission()) {
  if (await plugin.showIOSAppPicker()) {
    await plugin.blockIOSApps();
  }
}
await plugin.unblockIOSApps();

plugin.events.listen((event) {
  // event['name'] is one of: android_blocking_state_changed,
  // android_blocking_stopped, ios_blocking_state_changed, ios_permission_status,
  // ios_selection_updated, ios_schedule_configured, ios_picker_presented
  print(event);
});
```

Check the full example in the /example directory.

## 🧪 Testing

```sh
flutter test                                   # Dart unit tests
cd example && flutter test                     # example widget tests
cd example/android && ./gradlew :app_limiter:testDebugUnitTest   # Kotlin unit tests
cd example && flutter test integration_test    # on a device or emulator
```

To cover the Android blocking path in the integration tests, grant the
permissions first (`flutter test ... --no-uninstall` keeps them between runs):

```sh
adb shell appops set com.example.app_limiter_example SYSTEM_ALERT_WINDOW allow
adb shell appops set com.example.app_limiter_example GET_USAGE_STATS allow
```

## 🐞 Issues

Please report issues here:
https://github.com/connect-rizwan/AppLimiter-Plugin-Flutetr/issues
