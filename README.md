# App Limiter Plugin

A Flutter plugin to block apps and limit screen time on Android and iOS.

## 🧠 Features

- ✅ One typed API for permissions, blocking state and events on both platforms
- ✅ Android: block individual apps or every app (with an allowlist), list installed apps with icons
- ✅ Android: customizable block screen and notification, "blocked app opened" events
- ✅ iOS: pick, block and unblock apps, categories and websites (Screen Time API)
- ✅ Blocking survives reboots and app updates on Android
- ✅ Typed errors (`AppLimiterException` with an `AppLimiterErrorCode`)
- ✅ Optional Android enterprise (device owner) package suspension

## 🚀 Quick start

```dart
import 'package:app_limiter/app_limiter.dart';

final limiter = AppLimiter();

// 1. Permissions (call until granted; each call handles one permission)
var status = await limiter.getPermissionStatus();
if (!status.isGranted) {
  status = await limiter.requestPermission();
}

// 2. Block
if (Platform.isAndroid) {
  final apps = await limiter.android.getInstalledApps(includeIcons: true);
  // ...let the user choose, then:
  await limiter.android.blockApps(['com.google.android.youtube']);
} else if (Platform.isIOS) {
  if (await limiter.ios.showAppPicker()) {
    await limiter.ios.blockSelectedApps();
  }
}

// 3. Inspect and undo
final state = await limiter.getBlockingState();
await limiter.unblockAll();
```

## 🔧 API

### Common (Android and iOS)

```dart
static bool AppLimiter.isSupported
Future<String?> getPlatformVersion()
Future<PermissionStatus> getPermissionStatus()
Future<PermissionStatus> requestPermission([AppPermission? permission])
Future<BlockingState> getBlockingState()
Future<void> unblockAll()
Stream<AppLimiterEvent> events
```

- `PermissionStatus.isGranted` is true once every required permission is granted;
  `missing` / `optionalMissing` list the rest.
- On Android, `requestPermission()` opens the settings screen for the next missing
  permission (overlay → usage access → notifications) and completes when the
  user returns to the app.
- On iOS, it shows the Screen Time prompt. Once the user declines,
  `iosAuthorizationStatus` is `denied` and iOS will not prompt again.

### Android (`limiter.android`)

```dart
Future<void> blockApp(String packageName)
Future<void> blockApps(List<String> packageNames)
Future<void> unblockApp(String packageName)
Future<void> unblockApps(List<String> packageNames)
Future<void> blockAllApps({List<String> except = const []})
Future<void> setBlockScreen(BlockScreenConfig config)
Future<void> setNotification({String? title, String? text})
Future<List<InstalledApp>> getInstalledApps({bool includeIcons = false, bool includeSystemApps = true, int iconSize = 96})
Future<bool> isEnterpriseCapable()
Future<void> setEnterpriseModeEnabled(bool enabled)
Future<bool> isEnterpriseModeEnabled()
```

`InstalledApp` has `packageName`, `name`, `isSystemApp`, `category` and, when
requested, a PNG `icon` (`Image.memory(app.icon!)`).

#### Block screen

```dart
await limiter.android.setBlockScreen(
  BlockScreenConfig(
    title: 'Not now',
    message: 'You chose to stay focused until 6 pm.',
    backgroundColor: const Color(0xFF1A237E),
    textColor: Colors.white,
    icon: (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
    buttonLabel: 'Open MyApp',
    buttonAction: BlockScreenButtonAction.openHostApp, // or closeApp
  ),
);
await limiter.android.setNotification(title: 'Focus mode on');
```

The configuration is saved on the device and used from the next time a blocked
app opens. Unset fields keep the defaults; the default footer is your app's name.
The default texts can also be translated by overriding the string resources
`app_limiter_block_title`, `app_limiter_block_message`, `app_limiter_block_detail`,
`app_limiter_notification_title` and `app_limiter_notification_text`.

### iOS (`limiter.ios`)

```dart
Future<bool> showAppPicker()          // selection only; true if the user tapped Done
Future<void> blockSelectedApps()      // shield the saved selection
Future<void> showAppPickerAndBlock({IosSchedule? schedule})
Future<void> configureSchedule(IosSchedule schedule)
```

iOS never reveals which apps were chosen: the picker returns opaque tokens that
stay on the device. `BlockingState` reports how many apps, categories and
websites are selected.

Calling an `android` method on iOS (or the reverse) throws
`AppLimiterException` with `AppLimiterErrorCode.unsupported`.

### Errors

Every failure is an `AppLimiterException`:

| `AppLimiterErrorCode` | Meaning |
| --- | --- |
| `permissionDenied` | A required permission is missing |
| `noSelection` | `ios.blockSelectedApps()` called before choosing apps |
| `invalidArgument` | Empty package name |
| `noActivity` | Android call needs a foreground activity |
| `requestInProgress` | Another `requestPermission()` is still waiting for the user |
| `noViewController` | iOS picker could not be presented |
| `authorizationFailed` | iOS Screen Time request failed (restricted device, ...) |
| `enterpriseNotAvailable` / `enterpriseActionFailed` | Device owner operations failed |
| `unsupported` | Wrong platform or OS version |

### Events

`events` emits `AppLimiterEvent`s with a `type` (`blockingStateChanged`,
`blockingStopped`, `blockedAppOpened`, `permissionChanged`, `selectionChanged`,
`scheduleChanged`, `pickerPresented`), a `payload` map and a `timestamp`.

`blockedAppOpened` (Android) fires each time the user opens a blocked app, with
`payload['packageName']`. Events are only delivered while your app's Flutter
engine is running.

## 🪪 Setup

Minimum supported versions: Android 5.0 (API 21), iOS 16.0 for blocking (the pod builds on iOS 15).

### 🟢 Android

The plugin's manifest declares every permission, the foreground service (type
`specialUse`, required on Android 14+) and the receivers; nothing needs to be added
to your app's manifest.

Google Play notes:

- `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS` and the `specialUse` foreground
  service need a declaration in the Play Console explaining the app-blocking use.

Behaviour:

- `blockAllApps()` blocks every app with a launcher icon, including preinstalled
  ones such as YouTube or Gmail, but keeps the phone dialer and Settings usable.
  Pass `except:` to keep more apps usable; apps blocked with `blockApp` stay
  blocked even if listed. Block Settings explicitly with `blockApp` if needed.
- The host app, the home launcher and System UI are never blocked.
- Settings, the permission controller and the package installer hide third-party
  overlays. When they are blocked, the user is sent to the home screen instead.

### 🟣 iOS

1. In Xcode, add the **Family Controls** capability to the Runner target. This
   adds `com.apple.developer.family-controls` to your `.entitlements` file
   (entitlements do not go in `Info.plist`).
2. Distribution builds need the Family Controls (Distribution) entitlement
   [requested from Apple](https://developer.apple.com/contact/request/family-controls-distribution).
3. Schedules set with `configureSchedule` only take effect if your app ships a
   `DeviceActivityMonitor` extension that applies shields on interval events.
4. The iOS block screen (shield) uses Apple's default look. Customizing it needs a
   `ShieldConfiguration` extension in your app; the plugin cannot do it for you.

Both Swift Package Manager and CocoaPods are supported.

## ⬆️ Migrating from 0.x

The 0.x methods still work but are deprecated. The one breaking change is
`events`, which now emits `AppLimiterEvent` instead of `Map<String, dynamic>`
(use `event.toMap()` for the old shape). Errors are now `AppLimiterException`
instead of `PlatformException`/`ArgumentError`.

| 0.x | 1.0 |
| --- | --- |
| `isAndroidPermissionAllowed()` | `(await getPermissionStatus()).isGranted` |
| `requestAndroidPermission()` / `requestIosPermission()` | `requestPermission()` |
| `blockAndroidApp(packageName: p)` | `android.blockApp(p)` |
| `unblockAndroidApp(packageName: p)` | `android.unblockApp(p)` |
| `blockAllAndroidApps()` / `blocAndroidApp()` | `android.blockAllApps()` |
| `unblockAllAndroidApps()` / `unblocAndroidApp()` / `unblockIOSApps()` | `unblockAll()` |
| `getBlockedAndroidApps()` | `(await getBlockingState()).blockedPackages` |
| `isAndroidBlockingActive()` / `isIOSAppsBlocked()` | `(await getBlockingState()).isActive` |
| `showIOSAppPicker()` | `ios.showAppPicker()` |
| `blockIOSApps()` | `ios.blockSelectedApps()` |
| `selectAndConfigureIosAppRestrictions(schedule: {...})` | `ios.showAppPickerAndBlock(schedule: IosSchedule(...))` |
| `configureIosSchedule({...})` | `ios.configureSchedule(IosSchedule(...))` |
| `getIOSAuthorizationStatus()` | `(await getPermissionStatus()).iosAuthorizationStatus` |
| `setAndroidEnterpriseModeEnabled(enabled: e)` | `android.setEnterpriseModeEnabled(e)` |
| `getPlatformCapabilities()` | `getPermissionStatus()`, `getBlockingState()`, `android.isEnterpriseCapable()` |

## 📱 Platform Support

| Platform | Support |
| -------- | ------- |
| Android  | ✅      |
| iOS      | ✅      |
| Web, desktop | ❌ (`AppLimiter.isSupported` is false) |

Check the full example, including an installed-apps picker, in the /example directory.

## 🧪 Testing

```sh
flutter test                                   # Dart unit tests
cd example && flutter test                     # example widget tests
cd example/android && ./gradlew :app_limiter:testDebugUnitTest   # Kotlin unit tests
cd example && flutter test integration_test --no-uninstall      # on a device or emulator
```

To cover the Android blocking path in the integration tests, grant the
permissions first:

```sh
adb shell appops set com.example.app_limiter_example SYSTEM_ALERT_WINDOW allow
adb shell appops set com.example.app_limiter_example GET_USAGE_STATS allow
```

## 🐞 Issues

Please report issues here:
https://github.com/connect-rizwan/AppLimiter-Plugin-Flutetr/issues
