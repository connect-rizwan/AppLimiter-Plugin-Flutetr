import 'package:flutter/foundation.dart';

import '../app_limiter_platform_interface.dart';
import 'exception.dart';
import 'models.dart';

void _requirePlatform(TargetPlatform platform, String api) {
  if (kIsWeb || defaultTargetPlatform != platform) {
    throw AppLimiterException(
      AppLimiterErrorCode.unsupported,
      '$api is only available on ${platform.name}.',
    );
  }
}

List<String> _validPackageNames(Iterable<String> packageNames) {
  final trimmed = packageNames.map((name) => name.trim()).toList();
  if (trimmed.any((name) => name.isEmpty)) {
    throw const AppLimiterException(
      AppLimiterErrorCode.invalidArgument,
      'Package names must not be empty.',
    );
  }
  return trimmed;
}

/// Android-only APIs. Every method throws an [AppLimiterException] with
/// [AppLimiterErrorCode.unsupported] on other platforms.
class AndroidAppLimiter {
  const AndroidAppLimiter();

  AppLimiterPlatform get _platform => AppLimiterPlatform.instance;

  void _requireAndroid(String api) =>
      _requirePlatform(TargetPlatform.android, 'android.$api');

  /// Blocks [packageName], e.g. `com.google.android.youtube`.
  ///
  /// Throws [AppLimiterErrorCode.permissionDenied] if a required permission
  /// is missing and [AppLimiterErrorCode.invalidArgument] if the name is empty.
  Future<void> blockApp(String packageName) => blockApps([packageName]);

  /// Blocks every package in [packageNames]. Already blocked ones are kept.
  Future<void> blockApps(List<String> packageNames) async {
    _requireAndroid('blockApps');
    final names = _validPackageNames(packageNames);
    if (names.isEmpty) return;
    await _platform.androidBlockApps(names);
  }

  /// Unblocks [packageName]. Other blocked apps stay blocked.
  Future<void> unblockApp(String packageName) => unblockApps([packageName]);

  /// Unblocks every package in [packageNames].
  Future<void> unblockApps(List<String> packageNames) async {
    _requireAndroid('unblockApps');
    final names = _validPackageNames(packageNames);
    if (names.isEmpty) return;
    await _platform.androidUnblockApps(names);
  }

  /// Blocks every app with a launcher icon, preinstalled apps included.
  ///
  /// The host app, the home launcher, the phone dialer and Settings stay
  /// usable. Settings can still be blocked explicitly with [blockApp].
  /// Undo with `AppLimiter.unblockAll()`.
  Future<void> blockAllApps() {
    _requireAndroid('blockAllApps');
    return _platform.androidBlockAllApps();
  }

  /// Apps with a launcher icon, sorted by name, excluding the host app.
  ///
  /// Use it to build an app picker. Icons are PNG bytes and are only loaded
  /// when [includeIcons] is true, at [iconSize] pixels; loading runs off the
  /// main thread but takes longer with icons.
  Future<List<InstalledApp>> getInstalledApps({
    bool includeIcons = false,
    bool includeSystemApps = true,
    int iconSize = 96,
  }) {
    _requireAndroid('getInstalledApps');
    return _platform.androidGetInstalledApps(
      includeIcons: includeIcons,
      includeSystemApps: includeSystemApps,
      iconSize: iconSize,
    );
  }

  /// True when the host app is the device owner, which enterprise mode needs.
  Future<bool> isEnterpriseCapable() {
    _requireAndroid('isEnterpriseCapable');
    return _platform.androidIsEnterpriseCapable();
  }

  /// In enterprise mode blocked packages are also suspended by the system,
  /// which works even where overlays cannot.
  ///
  /// Throws [AppLimiterErrorCode.enterpriseNotAvailable] when enabling on a
  /// device where the app is not the device owner.
  Future<void> setEnterpriseModeEnabled(bool enabled) {
    _requireAndroid('setEnterpriseModeEnabled');
    return _platform.androidSetEnterpriseModeEnabled(enabled);
  }

  Future<bool> isEnterpriseModeEnabled() {
    _requireAndroid('isEnterpriseModeEnabled');
    return _platform.androidIsEnterpriseModeEnabled();
  }
}

/// iOS-only APIs (Screen Time). Every method throws an [AppLimiterException]
/// with [AppLimiterErrorCode.unsupported] on other platforms.
///
/// iOS does not expose app identities: apps are chosen by the user in
/// Apple's picker and only opaque tokens are stored on the device.
class IosAppLimiter {
  const IosAppLimiter();

  AppLimiterPlatform get _platform => AppLimiterPlatform.instance;

  void _requireIOS(String api) =>
      _requirePlatform(TargetPlatform.iOS, 'ios.$api');

  /// Shows Apple's app/category picker without blocking anything.
  ///
  /// Requests Screen Time access first if needed. Completes with true when
  /// the user tapped Done (the selection is saved) and false on Cancel.
  Future<bool> showAppPicker() {
    _requireIOS('showAppPicker');
    return _platform.iosShowAppPicker();
  }

  /// Shields the apps, categories and websites chosen with [showAppPicker].
  ///
  /// Throws [AppLimiterErrorCode.noSelection] if nothing was chosen yet.
  Future<void> blockSelectedApps() {
    _requireIOS('blockSelectedApps');
    return _platform.iosBlockSelectedApps();
  }

  /// Shows the picker and shields the selection when the user taps Done.
  Future<void> showAppPickerAndBlock({IosSchedule? schedule}) {
    _requireIOS('showAppPickerAndBlock');
    return _platform.iosShowAppPickerAndBlock(schedule: schedule?.toMap());
  }

  /// Starts DeviceActivity monitoring for [schedule].
  ///
  /// Only takes effect when the host app ships a `DeviceActivityMonitor`
  /// extension.
  Future<void> configureSchedule(IosSchedule schedule) {
    _requireIOS('configureSchedule');
    return _platform.iosConfigureSchedule(schedule.toMap());
  }
}
