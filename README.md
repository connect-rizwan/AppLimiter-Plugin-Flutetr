# App Limiter Plugin

A Flutter plugin to block apps and limit screen time on Android and iOS.

## 🧠 Features

- ✅ One typed API for permissions, blocking state and events on both platforms
- ✅ Android: block individual apps or every app (with an allowlist), list installed apps with icons
- ✅ Android: customizable block screen and notification, "blocked app opened" events
- ✅ Android: timed blocks and recurring schedules, enforced even while your app is closed
- ✅ iOS: pick, block and unblock apps, categories and websites (Screen Time API)
- ✅ iOS: custom block screen, timed blocks and schedules through ready-made app extensions
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
Future<void> blockApp(String packageName, {Duration? duration})
Future<void> blockApps(List<String> packageNames, {Duration? duration})
Future<void> unblockApp(String packageName)
Future<void> unblockApps(List<String> packageNames)
Future<void> blockAllApps({List<String> except = const [], Duration? duration})
Future<void> setSchedule(BlockSchedule schedule)
Future<void> removeSchedule(String id)
Future<List<BlockSchedule>> getSchedules()
Future<void> setBlockScreen(BlockScreenConfig config)
Future<void> setNotification({String? title, String? text})
Future<List<InstalledApp>> getInstalledApps({bool includeIcons = false, bool includeSystemApps = true, int iconSize = 96})
Future<bool> isEnterpriseCapable()
Future<void> setEnterpriseModeEnabled(bool enabled)
Future<bool> isEnterpriseModeEnabled()
```

`InstalledApp` has `packageName`, `name`, `isSystemApp`, `category` and, when
requested, a PNG `icon` (`Image.memory(app.icon!)`).

#### Timed blocks and schedules

```dart
// Ends on its own after 30 minutes, even if your app is closed.
await limiter.android.blockApp('com.instagram.android', duration: const Duration(minutes: 30));

// Every weekday night from 22:00 to 07:00.
await limiter.android.setSchedule(
  const BlockSchedule(
    id: 'bedtime',
    allApps: true,
    except: ['com.whatsapp'],
    start: DailyTime(22),
    end: DailyTime(7),
    weekdays: BlockSchedule.workdays, // starting days; DateTime.monday..sunday
  ),
);
```

- A window whose end is not after its start runs overnight; equal start and end
  block the whole day. Times use the device's time zone.
- Setting a schedule with an existing `id` replaces it. Schedules survive reboots
  and are not removed by `unblockAll()`; use `removeSchedule`.
- `getBlockingState()` reports `blockedUntil`, `blockAllUntil` and the
  `activeScheduleIds`, and `isActive` is true while any block applies right now.
- Blocks start and end within about 10 seconds of the set time while the
  screen is on; with the screen off they are applied on the next unlock.
- The blocking service (and its notification) keeps running while any
  schedule exists, so it can start blocking on time.
- Enterprise mode suspends manually blocked packages only; schedules use the
  block screen.

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
Future<void> blockSelectedApps({Duration? duration}) // shield the saved selection
Future<void> showAppPickerAndBlock({IosSchedule? schedule})

// Need the app extensions (see "iOS extensions" below)
Future<IosExtensionStatus> getExtensionStatus()
Future<void> setShield(IosShieldConfig config)
Future<void> setSchedule(IosBlockSchedule schedule)
Future<void> removeSchedule(String id)
Future<List<IosBlockSchedule>> getSchedules()
```

```dart
await limiter.ios.setShield(
  const IosShieldConfig(
    title: 'Not now',
    subtitle: '{app} is blocked until 6 pm.', // {app} = blocked app name
    primaryButtonLabel: 'Close',
    backgroundColor: Color(0xFF1A237E),
    titleColor: Colors.white,
  ),
);
await limiter.ios.blockSelectedApps(duration: const Duration(minutes: 30));
await limiter.ios.setSchedule(
  const IosBlockSchedule(id: 'bedtime', start: DailyTime(22), end: DailyTime(7)),
);
```

A schedule blocks the apps chosen in the picker when it is set (a snapshot).
Timed blocks and each part of a schedule window must last at least 15 minutes
(an Apple limit); overnight windows are split at midnight.

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
| `extensionMissing` | iOS App Group or app extension not set up |
| `authorizationFailed` | iOS Screen Time request failed (restricted device, ...) |
| `enterpriseNotAvailable` / `enterpriseActionFailed` | Device owner operations failed |
| `unsupported` | Wrong platform or OS version |

### Events

`events` emits `AppLimiterEvent`s with a `type` (`blockingStateChanged`,
`blockingStopped`, `blockedAppOpened`, `permissionChanged`, `selectionChanged`,
`scheduleChanged`, `pickerPresented`), a `payload` map and a `timestamp`.

`blockedAppOpened` (Android) fires each time the user opens a blocked app, with
`payload['packageName']`. `blockExpired` fires when a timed block ends, and
`scheduleStarted` / `scheduleEnded` (with `payload['id']`) when a schedule
window opens or closes. Events are only delivered while your app's Flutter
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

#### iOS extensions

A custom block screen, timed blocks and schedules need two small app extensions
in your app (Apple runs them while your app is closed). Add them with:

```sh
dart run app_limiter:setup_ios --app-group group.com.your.app
```

then open `ios/Runner.xcworkspace` once so Xcode can register the App Group and
the extension IDs. Check the result with `ios.getExtensionStatus()`. Details and
manual steps: [ios/extension_templates/README.md](ios/extension_templates/README.md).

Family Controls only works with a paid Apple Developer team; Personal (free)
teams cannot sign apps that use it.

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
