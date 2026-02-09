import 'app_limiter_platform_interface.dart';

/// A Flutter plugin for implementing app usage limitations and restrictions on iOS and Android platforms.
///
/// This plugin provides functionality to:
/// * Block and unblock apps on iOS devices
/// * Block and unblock apps on Android devices
/// * Handle platform-specific permissions
/// * Check platform version and compatibility
class AppLimiter {
  /// Gets the current platform version.
  ///
  /// Returns a [Future] that completes with the platform version as a [String],
  /// or null if the platform version could not be determined.
  Future<String?> getPlatformVersion() {
    return AppLimiterPlatform.instance.getPlatformVersion();
  }

  /// Toggles the block state of an iOS app.
  ///
  /// This method handles both blocking and unblocking operations for iOS apps.
  /// It uses the Screen Time API on iOS to manage app restrictions.
  /// Throws a [PlatformException] if the operation fails.
  Future<void> blockAndUnblockIOSApp() {
    return AppLimiterPlatform.instance.blockAndUnblockIOSApp();
  }

  /// Requests necessary permissions for app limiting functionality on iOS.
  ///
  /// Returns a [Future<bool>] that completes with:
  /// * true - if permissions were successfully granted
  /// * false - if permissions were denied or the request failed
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
  /// This method prompts the user to grant the required permissions for
  /// app usage access and other necessary Android permissions.
  /// Throws a [PlatformException] if the permission request fails.
  Future<void> requestAndroidPermission() {
    return AppLimiterPlatform.instance.requestAndroidPermission();
  }

  /// Blocks the specified Android app.
  ///
  /// Uses Android's UsageStats API to implement app blocking functionality.
  /// Throws a [PlatformException] if the blocking operation fails.
  Future<void> blocAndroidApp() {
    return AppLimiterPlatform.instance.blockAndroidApps();
  }

  /// Unblocks a previously blocked Android app.
  ///
  /// Removes usage restrictions from the specified Android app.
  /// Throws a [PlatformException] if the unblocking operation fails.
  Future<void> unblocAndroidApp() {
    return AppLimiterPlatform.instance.unblockAndroidApps();
  }

  // iOS App Blocking methods

  /// Shows the app picker UI for selecting apps to block.
  ///
  /// This method displays the Screen Time API's app selection interface.
  /// Selected apps are saved but not immediately blocked.
  /// Call [blockIOSApps] to actually start blocking the selected apps.
  ///
  /// **iOS only** - Requires iOS 15+
  /// Throws a [PlatformException] if the operation fails or on unsupported platforms.
  Future<void> showIOSAppPicker() {
    return AppLimiterPlatform.instance.showIOSAppPicker();
  }

  /// Blocks the previously selected apps.
  ///
  /// This method blocks all apps that were selected via [showIOSAppPicker].
  /// The blocking persists until [unblockIOSApps] is called.
  /// Similar to [blockAndroidApps] on Android platform.
  ///
  /// **iOS only** - Requires iOS 15+
  /// Throws a [PlatformException] if the operation fails or on unsupported platforms.
  Future<void> blockIOSApps() {
    return AppLimiterPlatform.instance.blockIOSApps();
  }

  /// Unblocks all apps.
  ///
  /// This method removes all app blocking restrictions.
  /// Selected apps are preserved and can be blocked again by calling
  /// [blockIOSApps].
  /// Similar to [unblockAndroidApps] on Android platform.
  ///
  /// **iOS only** - Requires iOS 15+
  /// Throws a [PlatformException] if the operation fails or on unsupported platforms.
  Future<void> unblockIOSApps() {
    return AppLimiterPlatform.instance.unblockIOSApps();
  }

  /// Checks if apps are currently blocked.
  ///
  /// Returns a [Future<bool>] that completes with:
  /// * true - if apps are currently blocked
  /// * false - if apps are not blocked
  ///
  /// **iOS only** - Requires iOS 15+
  Future<bool> isIOSAppsBlocked() {
    return AppLimiterPlatform.instance.isIOSAppsBlocked();
  }

  /// Gets the current Screen Time authorization status.
  ///
  /// Returns a [Future<String>] that completes with one of:
  /// * "notDetermined" - User has not been asked for permission yet
  /// * "authorized" - User has granted Screen Time permissions
  /// * "denied" - User has denied Screen Time permissions
  ///
  /// **iOS only** - Requires iOS 16+
  Future<String> getIOSAuthorizationStatus() {
    return AppLimiterPlatform.instance.getIOSAuthorizationStatus();
  }
}
