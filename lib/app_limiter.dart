import 'package:flutter/foundation.dart';

import 'app_limiter_platform_interface.dart';
import 'src/models.dart';
import 'src/platform_limiters.dart';

export 'src/exception.dart';
export 'src/models.dart';
export 'src/platform_limiters.dart';

/// Blocks apps on Android and iOS.
///
/// Common operations work on both platforms:
///
/// ```dart
/// final limiter = AppLimiter();
/// final status = await limiter.requestPermission();
/// if (status.isGranted) {
///   if (Platform.isAndroid) await limiter.android.blockApp('com.example');
///   if (Platform.isIOS && await limiter.ios.showAppPicker()) {
///     await limiter.ios.blockSelectedApps();
///   }
/// }
/// await limiter.unblockAll();
/// ```
///
/// Platform-specific operations live under [android] and [ios]. Every failure
/// is reported as an `AppLimiterException`.
class AppLimiter {
  AppLimiter();

  AppLimiterPlatform get _platform => AppLimiterPlatform.instance;

  /// True on Android and iOS, the platforms this plugin supports.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Android-only APIs.
  final AndroidAppLimiter android = const AndroidAppLimiter();

  /// iOS-only APIs.
  final IosAppLimiter ios = const IosAppLimiter();

  /// Gets the current platform version, e.g. `Android 15` or `iOS 18.1`.
  Future<String?> getPlatformVersion() => _platform.getPlatformVersion();

  /// Which permissions are granted.
  Future<PermissionStatus> getPermissionStatus() =>
      _platform.getPermissionStatus();

  /// Requests [permission], or the next missing one when null (required
  /// permissions first, then optional ones), and returns the updated status.
  ///
  /// Android: opens the matching settings screen and completes when the user
  /// returns to the app. Call it until [PermissionStatus.isGranted] is true;
  /// each call handles one permission. Throws
  /// [AppLimiterErrorCode.requestInProgress] while another request is open.
  ///
  /// iOS: shows the Screen Time prompt. After the user declines, iOS no longer
  /// prompts; [PermissionStatus.iosAuthorizationStatus] is then `denied`.
  Future<PermissionStatus> requestPermission([AppPermission? permission]) =>
      _platform.requestPermission(permission);

  /// What is currently blocked.
  Future<BlockingState> getBlockingState() => _platform.getBlockingState();

  /// Removes every block on the current platform.
  ///
  /// The iOS picker selection is kept, so `ios.blockSelectedApps()` can
  /// re-apply it.
  Future<void> unblockAll() => _platform.unblockAll();

  /// Native events: blocking state changes, permission and selection updates.
  Stream<AppLimiterEvent> get events => _platform.events;

  // Deprecated 0.x API

  @Deprecated('Use getPermissionStatus() or the typed APIs instead.')
  Future<Map<String, dynamic>> getPlatformCapabilities() =>
      _platform.getCapabilities();

  @Deprecated('Use ios.showAppPickerAndBlock() instead.')
  Future<void> selectAndConfigureIosAppRestrictions({
    Map<String, dynamic>? schedule,
  }) => _platform.iosShowAppPickerAndBlock(schedule: schedule);

  @Deprecated('Use ios.configureSchedule() instead.')
  Future<void> configureIosSchedule(Map<String, dynamic> schedule) =>
      _platform.iosConfigureSchedule(schedule);

  @Deprecated('Use ios.showAppPickerAndBlock() instead.')
  Future<void> blockAndUnblockIOSApp() => _platform.iosShowAppPickerAndBlock();

  @Deprecated('Use ios.showAppPicker() instead.')
  Future<bool> showIOSAppPicker() => ios.showAppPicker();

  @Deprecated('Use ios.blockSelectedApps() instead.')
  Future<void> blockIOSApps() => ios.blockSelectedApps();

  @Deprecated('Use unblockAll() instead.')
  Future<void> unblockIOSApps() => unblockAll();

  @Deprecated('Use getBlockingState() instead.')
  Future<bool> isIOSAppsBlocked() async => (await getBlockingState()).isActive;

  @Deprecated('Use getPermissionStatus() instead.')
  Future<String> getIOSAuthorizationStatus() async =>
      (await getPermissionStatus()).iosAuthorizationStatus?.name ??
      IosAuthorizationStatus.notDetermined.name;

  @Deprecated('Use requestPermission() instead.')
  Future<bool> requestIosPermission() async =>
      (await requestPermission()).isGranted;

  @Deprecated('Use getPermissionStatus() instead.')
  Future<bool> isAndroidPermissionAllowed() async =>
      (await getPermissionStatus()).isGranted;

  @Deprecated('Use requestPermission() instead.')
  Future<void> requestAndroidPermission() => requestPermission();

  @Deprecated('Use android.blockApp() instead.')
  Future<void> blockAndroidApp({required String packageName}) =>
      android.blockApp(packageName);

  @Deprecated('Use android.unblockApp() instead.')
  Future<void> unblockAndroidApp({required String packageName}) =>
      android.unblockApp(packageName);

  @Deprecated('Use android.blockAllApps() instead.')
  Future<void> blockAllAndroidApps() => android.blockAllApps();

  @Deprecated('Use unblockAll() instead.')
  Future<void> unblockAllAndroidApps() => unblockAll();

  @Deprecated('Use getBlockingState() instead.')
  Future<List<String>> getBlockedAndroidApps() async =>
      (await getBlockingState()).blockedPackages;

  @Deprecated('Use getBlockingState() instead.')
  Future<bool> isAndroidBlockingActive() async =>
      (await getBlockingState()).isActive;

  @Deprecated('Use android.blockAllApps() instead.')
  Future<void> blocAndroidApp() => android.blockAllApps();

  @Deprecated('Use unblockAll() instead.')
  Future<void> unblocAndroidApp() => unblockAll();

  @Deprecated('Use android.setEnterpriseModeEnabled() instead.')
  Future<void> setAndroidEnterpriseModeEnabled({required bool enabled}) =>
      android.setEnterpriseModeEnabled(enabled);

  @Deprecated('Use android.isEnterpriseModeEnabled() instead.')
  Future<bool> isAndroidEnterpriseModeEnabled() =>
      android.isEnterpriseModeEnabled();
}
