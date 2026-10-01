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

void _validateDuration(Duration? duration) {
  if (duration != null && duration <= Duration.zero) {
    throw const AppLimiterException(
      AppLimiterErrorCode.invalidArgument,
      'duration must be positive.',
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
  /// With a [duration] the block ends on its own, even while your app is
  /// closed; without one it lasts until [unblockApp]. Blocking an already
  /// blocked package replaces its end time.
  ///
  /// Throws [AppLimiterErrorCode.permissionDenied] if a required permission
  /// is missing and [AppLimiterErrorCode.invalidArgument] if the name is empty
  /// or the duration is not positive.
  Future<void> blockApp(String packageName, {Duration? duration}) =>
      blockApps([packageName], duration: duration);

  /// Blocks every package in [packageNames]. Already blocked ones are kept.
  /// See [blockApp] for [duration].
  Future<void> blockApps(
    List<String> packageNames, {
    Duration? duration,
  }) async {
    _requireAndroid('blockApps');
    _validateDuration(duration);
    final names = _validPackageNames(packageNames);
    if (names.isEmpty) return;
    await _platform.androidBlockApps(names, duration: duration);
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

  /// Blocks every app with a launcher icon, preinstalled apps included,
  /// except the packages in [except].
  ///
  /// The host app, the home launcher, the phone dialer and Settings always
  /// stay usable. Apps blocked with [blockApp] stay blocked even if listed in
  /// [except]. Calling it again replaces the previous [except] list.
  /// With a [duration] it ends on its own; otherwise undo it with
  /// `AppLimiter.unblockAll()`.
  Future<void> blockAllApps({
    List<String> except = const [],
    Duration? duration,
  }) {
    _requireAndroid('blockAllApps');
    _validateDuration(duration);
    return _platform.androidBlockAllApps(
      except: _validPackageNames(except),
      duration: duration,
    );
  }

  /// Adds [schedule], or replaces the schedule with the same id.
  ///
  /// Schedules are enforced on the device, including after a reboot, until
  /// removed with [removeSchedule]. `AppLimiter.unblockAll()` does not remove
  /// them. Throws [AppLimiterErrorCode.permissionDenied] if a required
  /// permission is missing.
  Future<void> setSchedule(BlockSchedule schedule) {
    _requireAndroid('setSchedule');
    _validPackageNames([...schedule.packages, ...schedule.except]);
    final error = switch (schedule) {
      _ when schedule.id.trim().isEmpty => 'id must not be empty.',
      _ when !schedule.allApps && schedule.packages.isEmpty =>
        'Set packages or allApps.',
      _
          when schedule.weekdays.isEmpty ||
              schedule.weekdays.any((day) => day < 1 || day > 7) =>
        'weekdays must use DateTime.monday (1) to DateTime.sunday (7).',
      _ => null,
    };
    if (error != null) {
      throw AppLimiterException(AppLimiterErrorCode.invalidArgument, error);
    }
    return _platform.androidSetSchedule(schedule);
  }

  /// Removes the schedule with [id]. Does nothing if it does not exist.
  Future<void> removeSchedule(String id) {
    _requireAndroid('removeSchedule');
    return _platform.androidRemoveSchedule(id);
  }

  /// All schedules, sorted by id.
  Future<List<BlockSchedule>> getSchedules() {
    _requireAndroid('getSchedules');
    return _platform.androidGetSchedules();
  }

  /// Customizes the block screen shown over blocked apps.
  ///
  /// Saved on the device and used from the next time a blocked app opens.
  /// Pass `const BlockScreenConfig()` to restore the defaults.
  Future<void> setBlockScreen(BlockScreenConfig config) {
    _requireAndroid('setBlockScreen');
    return _platform.androidSetBlockScreen(config);
  }

  /// Sets the text of the notification shown while blocking is active.
  /// Null restores the default.
  Future<void> setNotification({String? title, String? text}) {
    _requireAndroid('setNotification');
    return _platform.androidSetNotification(title: title, text: text);
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
  /// With a [duration] (at least 15 minutes, an Apple limit) the block ends
  /// on its own, even while your app is closed; this needs the Device
  /// Activity Monitor extension. Without one it lasts until
  /// `AppLimiter.unblockAll()`.
  ///
  /// Throws [AppLimiterErrorCode.noSelection] if nothing was chosen yet and
  /// [AppLimiterErrorCode.extensionMissing] if a duration is given but the
  /// extension is not set up.
  Future<void> blockSelectedApps({Duration? duration}) {
    _requireIOS('blockSelectedApps');
    if (duration != null && duration < const Duration(minutes: 15)) {
      throw const AppLimiterException(
        AppLimiterErrorCode.invalidArgument,
        'iOS timed blocks must last at least 15 minutes.',
      );
    }
    return _platform.iosBlockSelectedApps(duration: duration);
  }

  /// Which extensions and App Group are set up in your app.
  Future<IosExtensionStatus> getExtensionStatus() {
    _requireIOS('getExtensionStatus');
    return _platform.iosGetExtensionStatus();
  }

  /// Customizes the block screen. Needs the Shield Configuration extension.
  ///
  /// Pass `const IosShieldConfig()` to restore Apple's default.
  Future<void> setShield(IosShieldConfig config) {
    _requireIOS('setShield');
    return _platform.iosSetShield(config);
  }

  /// Adds [schedule], or replaces the one with the same id, for the apps
  /// currently chosen with [showAppPicker] (a snapshot: picking other apps
  /// later does not change it).
  ///
  /// Needs the Device Activity Monitor extension. Schedules keep working while
  /// your app is closed and are not removed by `AppLimiter.unblockAll()`.
  Future<void> setSchedule(IosBlockSchedule schedule) {
    _requireIOS('setSchedule');
    final error = switch (schedule) {
      _ when schedule.id.trim().isEmpty => 'id must not be empty.',
      _
          when schedule.weekdays.isEmpty ||
              schedule.weekdays.any((day) => day < 1 || day > 7) =>
        'weekdays must use DateTime.monday (1) to DateTime.sunday (7).',
      _ => null,
    };
    if (error != null) {
      throw AppLimiterException(AppLimiterErrorCode.invalidArgument, error);
    }
    return _platform.iosSetSchedule(schedule);
  }

  /// Removes the schedule with [id] and lifts its block.
  Future<void> removeSchedule(String id) {
    _requireIOS('removeSchedule');
    return _platform.iosRemoveSchedule(id);
  }

  /// All iOS schedules, sorted by id.
  Future<List<IosBlockSchedule>> getSchedules() {
    _requireIOS('getSchedules');
    return _platform.iosGetSchedules();
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
