## [1.0.0] - Unreleased

### Breaking
- Android namespace changed from `com.example.app_limiter` to
  `io.github.connectrizwan.app_limiter`. Saved blocking state is kept.
- `events` emits typed `AppLimiterEvent`s instead of maps (`event.toMap()` gives the old shape).
- Errors are thrown as `AppLimiterException` (with `AppLimiterErrorCode`) instead of
  `PlatformException` / `ArgumentError`.
- The platform interface was redesigned; custom `AppLimiterPlatform` implementations must be updated.

### Added
- Typed cross-platform API: `getPermissionStatus()`, `requestPermission()`,
  `getBlockingState()`, `unblockAll()`, `AppLimiter.isSupported`.
- Platform namespaces `limiter.android` and `limiter.ios`.
- `android.getInstalledApps()` with names, categories, system flag and optional PNG icons.
- `android.blockApps()` / `android.unblockApps()` for several packages at once.
- `android.isEnterpriseCapable()`.
- Android `requestPermission()` completes when the user returns from the settings screen.
- `IosSchedule` type for iOS schedules.
- Android `setBlockScreen(BlockScreenConfig)`: custom title, message, footer, colors,
  icon and an optional button that closes the blocked app or opens the host app.
- Android `setNotification()` to change the blocking notification text.
- Android `blockAllApps(except: [...])` allowlist; `BlockingState.allowedPackages`.
- `AppLimiterEventType.blockedAppOpened` event with the package name (Android).
- Default texts are string resources that host apps can translate or override.
- Android timed blocks: `duration:` on `blockApp`, `blockApps` and `blockAllApps`.
- Android recurring schedules: `setSchedule(BlockSchedule)`, `removeSchedule`,
  `getSchedules`, with overnight windows, weekdays and "all apps except".
- `BlockingState.blockedUntil`, `blockAllUntil` and `activeScheduleIds`.
- Events `blockExpired`, `scheduleStarted` and `scheduleEnded` (Android).

### Fixed
- Crash `ForegroundServiceDidNotStartInTimeException` when blocking was turned off
  right after it was turned on (for example a quick toggle) on Android 12+.
- The block screen footer showed "Digital Wellbeing" (Google's product name); it now
  shows the host app's name.
- A host app overriding the `block_overlay` layout no longer prevents the block screen
  from showing.

### Deprecated
- All 0.x methods; they keep working and forward to the new API. See the migration table in the README.

## [0.1.0] - 2026-10-01

### Fixed
- Android 14+ crash `MissingForegroundServiceTypeException` when blocking (#1, #4).
  The blocking service is now a `specialUse` foreground service.
- Overlay disappearing about 10 seconds after opening a blocked app.
- Unblocking one Android package stopped blocking for every package.
- Repeated block calls started duplicate blocking loops and leaked overlay views.
- Blocking service kept running (with its notification) after permissions were revoked.
- Settings could not be blocked; it is now exited to the home screen because it
  hides third-party overlays.
- iOS selection API called Android's `blockApp` method, which blocked every app on Android.
- iOS picker never appeared in UIScene-based apps (Flutter's default template).
- iOS UI work ran off the main thread after the authorization prompt.
- iOS picker applied shields while the user was still choosing, and Cancel did not undo them.
- iOS plugin failed to compile (`[AnyHashable: Any]` passed as `[String: Any]`).
- `events` threw `MissingPluginException` on Android.
- "Block all" skipped preinstalled apps (YouTube, Gmail, ...) because only non-system
  apps were blocked; it now covers every app with a launcher icon except the dialer and Settings.

### Added
- iOS: `showIOSAppPicker()`, `blockIOSApps()`, `unblockIOSApps()`, `isIOSAppsBlocked()`,
  `getIOSAuthorizationStatus()` to separate selection from blocking (#6).
- Android: `blockAllAndroidApps()`, `unblockAllAndroidApps()`, `getBlockedAndroidApps()`,
  `isAndroidBlockingActive()`.
- Android blocking events (`android_blocking_state_changed`, `android_blocking_stopped`).
- Blocking resumes after app updates as well as reboots.
- Notification permission request on Android 13+.
- Swift Package Manager support for iOS.
- Unit tests (Dart and Kotlin) and on-device integration tests.

### Changed
- `blockAndroidApp`/`unblockAndroidApp` reject empty package names; use the `All` variants.
- Blocking on Android fails with `PERMISSION_DENIED` instead of silently doing nothing.
- `requestIosPermission()` returns false when the user declines instead of throwing.
- Removed `SCHEDULE_EXACT_ALARM` from the plugin manifest.
- Deprecated `blocAndroidApp()`, `unblocAndroidApp()` and `blockAndUnblockIOSApp()`.

## [0.0.1] - 2025-05-14

- Initial release.
- Supports blocking/unblocking Android and iOS apps.
- Handles permission requests on both platforms.
- Added helper methods to check and request platform-specific permissions.

## [0.0.2] - 2025-05-21

- Added Dartdoc comments for public API

## [0.0.3] - 2025-05-21

- Added Dartdoc comments for public API
- Readme File updated for easy configuration

## [0.0.4] - 2025-05-31

- Block Overlay Hide Issue Fixed
- Readme File updated for configuration
