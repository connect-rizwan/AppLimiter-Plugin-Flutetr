import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_limiter_method_channel.dart';
import 'src/models.dart';

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

  UnimplementedError _unimplemented(String method) =>
      UnimplementedError('$method() has not been implemented.');

  // Common

  Future<String?> getPlatformVersion() =>
      throw _unimplemented('getPlatformVersion');

  Future<PermissionStatus> getPermissionStatus() =>
      throw _unimplemented('getPermissionStatus');

  /// Requests [permission], or the next missing required permission when null.
  Future<PermissionStatus> requestPermission([AppPermission? permission]) =>
      throw _unimplemented('requestPermission');

  Future<BlockingState> getBlockingState() =>
      throw _unimplemented('getBlockingState');

  Future<void> unblockAll() => throw _unimplemented('unblockAll');

  Stream<AppLimiterEvent> get events => throw _unimplemented('events');

  /// Raw capability map, kept for the deprecated `getPlatformCapabilities()`.
  Future<Map<String, dynamic>> getCapabilities() =>
      throw _unimplemented('getCapabilities');

  // Android

  Future<void> androidBlockApps(
    List<String> packageNames, {
    Duration? duration,
  }) => throw _unimplemented('androidBlockApps');

  Future<void> androidUnblockApps(List<String> packageNames) =>
      throw _unimplemented('androidUnblockApps');

  Future<void> androidBlockAllApps({
    List<String> except = const [],
    Duration? duration,
  }) => throw _unimplemented('androidBlockAllApps');

  Future<void> androidSetSchedule(BlockSchedule schedule) =>
      throw _unimplemented('androidSetSchedule');

  Future<void> androidRemoveSchedule(String id) =>
      throw _unimplemented('androidRemoveSchedule');

  Future<List<BlockSchedule>> androidGetSchedules() =>
      throw _unimplemented('androidGetSchedules');

  Future<void> androidSetBlockScreen(BlockScreenConfig config) =>
      throw _unimplemented('androidSetBlockScreen');

  Future<void> androidSetNotification({String? title, String? text}) =>
      throw _unimplemented('androidSetNotification');

  Future<List<InstalledApp>> androidGetInstalledApps({
    bool includeIcons = false,
    bool includeSystemApps = true,
    int iconSize = 96,
  }) => throw _unimplemented('androidGetInstalledApps');

  Future<bool> androidIsEnterpriseCapable() =>
      throw _unimplemented('androidIsEnterpriseCapable');

  Future<void> androidSetEnterpriseModeEnabled(bool enabled) =>
      throw _unimplemented('androidSetEnterpriseModeEnabled');

  Future<bool> androidIsEnterpriseModeEnabled() =>
      throw _unimplemented('androidIsEnterpriseModeEnabled');

  // iOS

  Future<bool> iosShowAppPicker() => throw _unimplemented('iosShowAppPicker');

  Future<void> iosBlockSelectedApps() =>
      throw _unimplemented('iosBlockSelectedApps');

  Future<void> iosShowAppPickerAndBlock({Map<String, dynamic>? schedule}) =>
      throw _unimplemented('iosShowAppPickerAndBlock');

  Future<void> iosConfigureSchedule(Map<String, dynamic> schedule) =>
      throw _unimplemented('iosConfigureSchedule');
}
