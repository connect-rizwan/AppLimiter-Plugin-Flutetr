import 'app_limiter_platform_interface.dart';

/// A Flutter plugin for implementing app usage limitations and restrictions on iOS and Android platforms.
///
/// This plugin provides functionality to:
/// * Block and unblock apps on iOS devices
/// * Block and unblock apps on Android devices
/// * Handle platform-specific permissions
/// * Check platform version and compatibility
///
/// Methods prefixed with `IOS`/`Ios` only work on iOS and methods prefixed
/// with `Android` only work on Android. Calling them on the other platform
/// throws a `MissingPluginException`.
class AppLimiter {
  /// Gets the current platform version.
  ///
  /// Returns a [Future] that completes with the platform version as a [String],
  /// or null if the platform version could not be determined.
  Future<String?> getPlatformVersion() {
    return AppLimiterPlatform.instance.getPlatformVersion();
  }

  /// Opens iOS app/category picker and shields the selection when the user
  /// taps Done.
  ///
  /// Completes once the picker is dismissed. [schedule] supports keys:
  /// startHour, startMinute, endHour, endMinute, repeats, thresholdMinutes.
  Future<void> selectAndConfigureIosAppRestrictions({
    Map<String, dynamic>? schedule,
  }) {
    return AppLimiterPlatform.instance.selectAndConfigureIosAppRestrictions(
      schedule: schedule,
    );
  }

  /// Updates iOS schedule without opening the picker.
  Future<void> configureIosSchedule(Map<String, dynamic> schedule) {
    return AppLimiterPlatform.instance.configureIosSchedule(schedule);
  }

  /// Toggles iOS app restrictions.
  @Deprecated('Use selectAndConfigureIosAppRestrictions instead.')
  Future<void> blockAndUnblockIOSApp() {
    return AppLimiterPlatform.instance.blockAndUnblockIOSApp();
  }

  /// Shows the iOS app/category picker without blocking anything.
  ///
  /// The selection is saved on the device and used by [blockIOSApps].
  /// Requests Screen Time authorization first if needed.
  ///
  /// Completes with true when the user tapped Done and false when the
  /// picker was cancelled.
  Future<bool> showIOSAppPicker() {
    return AppLimiterPlatform.instance.showIOSAppPicker();
  }

  /// Shields the apps and categories chosen with [showIOSAppPicker].
  ///
  /// Throws a `PlatformException` with code `NO_SELECTION` if nothing has
  /// been selected yet, or `PERMISSION_DENIED` if Screen Time access has not
  /// been granted.
  Future<void> blockIOSApps() {
    return AppLimiterPlatform.instance.blockIOSApps();
  }

  /// Removes every iOS shield applied by this plugin.
  ///
  /// The saved selection is kept so [blockIOSApps] can be called again.
  Future<void> unblockIOSApps() {
    return AppLimiterPlatform.instance.unblockIOSApps();
  }

  /// Returns true if any iOS app or category is currently shielded.
  Future<bool> isIOSAppsBlocked() {
    return AppLimiterPlatform.instance.isIOSAppsBlocked();
  }

  /// Returns the Screen Time authorization status on iOS.
  ///
  /// One of `notDetermined`, `denied` or `approved`.
  Future<String> getIOSAuthorizationStatus() {
    return AppLimiterPlatform.instance.getIOSAuthorizationStatus();
  }

  /// Requests necessary permissions for app limiting functionality on iOS.
  ///
  /// Returns a [Future<bool>] that completes with:
  /// * true - if permissions were successfully granted
  /// * false - if permissions were denied
  ///
  /// Throws a `PlatformException` if the request itself fails.
  Future<bool> requestIosPermission() {
    return AppLimiterPlatform.instance.requestIosPermission();
  }

  /// Checks if the required Android permissions are granted.
  ///
  /// Returns a [Future<bool>] that completes with:
  /// * true - if all required permissions are granted
  /// * false - if any required permission is missing
  Future<bool> isAndroidPermissionAllowed() {
    return AppLimiterPlatform.instance.isAndroidPermissionAllowed();
  }

  /// Requests necessary permissions for app limiting functionality on Android.
  ///
  /// Each call opens the settings screen for the next missing permission
  /// (overlay, then usage access, then notifications on Android 13+).
  /// Throws a [PlatformException] if the permission request fails.
  Future<void> requestAndroidPermission() {
    return AppLimiterPlatform.instance.requestAndroidPermission();
  }

  /// Blocks the specified Android app package.
  ///
  /// Throws an [ArgumentError] if [packageName] is empty.
  Future<void> blockAndroidApp({required String packageName}) {
    return AppLimiterPlatform.instance.blockAndroidApp(
      packageName: packageName,
    );
  }

  /// Unblocks a previously blocked Android app package.
  ///
  /// Blocking stays active for any other blocked package.
  /// Throws an [ArgumentError] if [packageName] is empty.
  Future<void> unblockAndroidApp({required String packageName}) {
    return AppLimiterPlatform.instance.unblockAndroidApp(
      packageName: packageName,
    );
  }

  /// Blocks every Android app with a launcher icon, preinstalled apps included.
  ///
  /// The host app, the home launcher, the phone dialer and Settings stay usable.
  /// Settings can still be blocked explicitly with [blockAndroidApp].
  Future<void> blockAllAndroidApps() {
    return AppLimiterPlatform.instance.blockAllAndroidApps();
  }

  /// Removes every Android block and stops the blocking service.
  Future<void> unblockAllAndroidApps() {
    return AppLimiterPlatform.instance.unblockAllAndroidApps();
  }

  /// Returns the package names blocked with [blockAndroidApp].
  Future<List<String>> getBlockedAndroidApps() {
    return AppLimiterPlatform.instance.getBlockedAndroidApps();
  }

  /// Returns true while the Android blocking service is enforcing blocks.
  Future<bool> isAndroidBlockingActive() {
    return AppLimiterPlatform.instance.isAndroidBlockingActive();
  }

  /// Legacy misspelled wrapper kept for compatibility. Blocks all apps.
  @Deprecated('Use blockAllAndroidApps instead.')
  Future<void> blocAndroidApp() {
    return AppLimiterPlatform.instance.blockAllAndroidApps();
  }

  /// Legacy misspelled wrapper kept for compatibility. Unblocks all apps.
  @Deprecated('Use unblockAllAndroidApps instead.')
  Future<void> unblocAndroidApp() {
    return AppLimiterPlatform.instance.unblockAllAndroidApps();
  }

  /// Returns plugin capabilities for the current platform.
  Future<Map<String, dynamic>> getPlatformCapabilities() {
    return AppLimiterPlatform.instance.getPlatformCapabilities();
  }

  /// Enables or disables Android enterprise mode.
  Future<void> setAndroidEnterpriseModeEnabled({required bool enabled}) {
    return AppLimiterPlatform.instance.setAndroidEnterpriseModeEnabled(
      enabled: enabled,
    );
  }

  /// Returns true if Android enterprise mode is active.
  Future<bool> isAndroidEnterpriseModeEnabled() {
    return AppLimiterPlatform.instance.isAndroidEnterpriseModeEnabled();
  }

  /// Stream of plugin events such as blocking state, permission updates and
  /// iOS schedule events.
  ///
  /// Each event is a map with `name`, `payload` and `timestamp` keys.
  Stream<Map<String, dynamic>> get events {
    return AppLimiterPlatform.instance.getEventStream();
  }
}
