import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_limiter_method_channel.dart';

/// The interface that implementations of app_limiter must implement.
///
/// Platform implementations should extend this class rather than implement it as `app_limiter`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [AppLimiterPlatform] methods.
abstract class AppLimiterPlatform extends PlatformInterface {
  /// Constructs a AppLimiterPlatform.
  AppLimiterPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppLimiterPlatform _instance = MethodChannelAppLimiter();

  /// The default instance of [AppLimiterPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppLimiter].
  static AppLimiterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppLimiterPlatform] when they
  /// register themselves.
  static set instance(AppLimiterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Gets the platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Handles blocking and unblocking operations for iOS apps.
  @Deprecated('Use selectAndConfigureIosAppRestrictions instead.')
  Future<void> blockAndUnblockIOSApp() {
    return selectAndConfigureIosAppRestrictions();
  }

  /// Opens iOS app/category picker and applies current restrictions.
  ///
  /// [schedule] supports keys: startHour, startMinute, endHour, endMinute,
  /// repeats, thresholdMinutes.
  Future<void> selectAndConfigureIosAppRestrictions({
    Map<String, dynamic>? schedule,
  }) {
    throw UnimplementedError(
      'selectAndConfigureIosAppRestrictions() has not been implemented.',
    );
  }

  /// Updates iOS schedule without reopening app/category picker.
  Future<void> configureIosSchedule(Map<String, dynamic> schedule) {
    throw UnimplementedError(
      'configureIosSchedule() has not been implemented.',
    );
  }

  /// Shows the iOS app/category picker without applying any restriction.
  ///
  /// Completes with true when the user confirmed a selection and false when
  /// the picker was cancelled.
  Future<bool> showIOSAppPicker() {
    throw UnimplementedError('showIOSAppPicker() has not been implemented.');
  }

  /// Shields the apps and categories previously chosen in the iOS picker.
  Future<void> blockIOSApps() {
    throw UnimplementedError('blockIOSApps() has not been implemented.');
  }

  /// Removes every shield applied by this plugin on iOS.
  Future<void> unblockIOSApps() {
    throw UnimplementedError('unblockIOSApps() has not been implemented.');
  }

  /// Returns true if any iOS app or category is currently shielded.
  Future<bool> isIOSAppsBlocked() {
    throw UnimplementedError('isIOSAppsBlocked() has not been implemented.');
  }

  /// Returns the iOS Screen Time authorization status.
  Future<String> getIOSAuthorizationStatus() {
    throw UnimplementedError(
      'getIOSAuthorizationStatus() has not been implemented.',
    );
  }

  /// Requests necessary permissions on iOS.
  Future<bool> requestIosPermission() {
    throw UnimplementedError(
      'requestIosPermission() has not been implemented.',
    );
  }

  /// Checks if required Android permissions are granted.
  Future<bool> isAndroidPermissionAllowed() {
    throw UnimplementedError(
      'isAndroidPermissionAllowed() has not been implemented.',
    );
  }

  /// Requests necessary Android permissions.
  Future<void> requestAndroidPermission() {
    throw UnimplementedError(
      'requestAndroidPermission() has not been implemented.',
    );
  }

  /// Blocks every Android app with a launcher icon, except essential ones.
  @Deprecated('Use blockAllAndroidApps instead.')
  Future<void> blockAndroidApps() {
    return blockAllAndroidApps();
  }

  /// Blocks a specific Android app package.
  Future<void> blockAndroidApp({required String packageName}) {
    throw UnimplementedError('blockAndroidApp() has not been implemented.');
  }

  /// Blocks every Android app with a launcher icon, except essential ones.
  Future<void> blockAllAndroidApps() {
    throw UnimplementedError('blockAllAndroidApps() has not been implemented.');
  }

  /// Removes every Android block.
  @Deprecated('Use unblockAllAndroidApps instead.')
  Future<void> unblockAndroidApps() {
    return unblockAllAndroidApps();
  }

  /// Unblocks a specific Android app package.
  Future<void> unblockAndroidApp({required String packageName}) {
    throw UnimplementedError('unblockAndroidApp() has not been implemented.');
  }

  /// Removes every Android block and stops the blocking service.
  Future<void> unblockAllAndroidApps() {
    throw UnimplementedError(
      'unblockAllAndroidApps() has not been implemented.',
    );
  }

  /// Returns the package names that are individually blocked on Android.
  Future<List<String>> getBlockedAndroidApps() {
    throw UnimplementedError(
      'getBlockedAndroidApps() has not been implemented.',
    );
  }

  /// Returns true if Android blocking is currently active.
  Future<bool> isAndroidBlockingActive() {
    throw UnimplementedError(
      'isAndroidBlockingActive() has not been implemented.',
    );
  }

  /// Returns platform capabilities and currently active plugin features.
  Future<Map<String, dynamic>> getPlatformCapabilities() {
    throw UnimplementedError(
      'getPlatformCapabilities() has not been implemented.',
    );
  }

  /// Enables or disables optional Android enterprise mode.
  Future<void> setAndroidEnterpriseModeEnabled({required bool enabled}) {
    throw UnimplementedError(
      'setAndroidEnterpriseModeEnabled() has not been implemented.',
    );
  }

  /// Returns true if Android enterprise mode is currently active.
  Future<bool> isAndroidEnterpriseModeEnabled() {
    throw UnimplementedError(
      'isAndroidEnterpriseModeEnabled() has not been implemented.',
    );
  }

  /// Event stream for permission, schedule, and selection state updates.
  Stream<Map<String, dynamic>> getEventStream() {
    throw UnimplementedError('getEventStream() has not been implemented.');
  }
}
