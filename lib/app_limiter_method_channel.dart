import 'package:flutter/services.dart';

import 'app_limiter_platform_interface.dart';

/// An implementation of [AppLimiterPlatform] that uses method channels.
class MethodChannelAppLimiter extends AppLimiterPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('app_limiter');
  final eventChannel = const EventChannel('app_limiter/events');

  late final Stream<Map<String, dynamic>> _events = eventChannel
      .receiveBroadcastStream()
      .map((dynamic event) {
        if (event is Map) {
          return _stringKeyed(event);
        }
        return <String, dynamic>{'name': 'unknown', 'payload': event};
      });

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> map) {
    return map.map(
      (dynamic key, dynamic value) =>
          MapEntry(key.toString(), value is Map ? _stringKeyed(value) : value),
    );
  }

  static void _requirePackageName(String packageName) {
    if (packageName.trim().isEmpty) {
      throw ArgumentError.value(
        packageName,
        'packageName',
        'must not be empty',
      );
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> selectAndConfigureIosAppRestrictions({
    Map<String, dynamic>? schedule,
  }) async {
    await methodChannel.invokeMethod<void>(
      'selectAndConfigureIosAppRestrictions',
      {'schedule': schedule},
    );
  }

  @override
  Future<void> configureIosSchedule(Map<String, dynamic> schedule) async {
    await methodChannel.invokeMethod<void>('configureIosSchedule', {
      'schedule': schedule,
    });
  }

  @override
  Future<void> blockAndUnblockIOSApp() async {
    await selectAndConfigureIosAppRestrictions();
  }

  @override
  Future<bool> showIOSAppPicker() async {
    final confirmed = await methodChannel.invokeMethod<bool>('showAppPicker');
    return confirmed ?? false;
  }

  @override
  Future<void> blockIOSApps() async {
    await methodChannel.invokeMethod<void>('blockIOSApps');
  }

  @override
  Future<void> unblockIOSApps() async {
    await methodChannel.invokeMethod<void>('unblockIOSApps');
  }

  @override
  Future<bool> isIOSAppsBlocked() async {
    final blocked = await methodChannel.invokeMethod<bool>('isIOSAppsBlocked');
    return blocked ?? false;
  }

  @override
  Future<String> getIOSAuthorizationStatus() async {
    final status = await methodChannel.invokeMethod<String>(
      'getAuthorizationStatus',
    );
    return status ?? 'notDetermined';
  }

  /// Requests iOS permissions through the native implementation
  @override
  Future<bool> requestIosPermission() async {
    final result = await methodChannel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  /// Checks Android permission status through the native implementation
  @override
  Future<bool> isAndroidPermissionAllowed() async {
    final result = await methodChannel.invokeMethod<dynamic>('checkPermission');
    if (result is bool) {
      return result;
    }
    if (result is String) {
      return result.toLowerCase() == 'approved';
    }
    return false;
  }

  /// Requests Android permissions through the native implementation
  @override
  Future<void> requestAndroidPermission() async {
    await methodChannel.invokeMethod<void>('requestAuthorization');
  }

  @override
  Future<void> blockAndroidApp({required String packageName}) async {
    _requirePackageName(packageName);
    await methodChannel.invokeMethod<void>('blockApp', {
      'packageName': packageName.trim(),
    });
  }

  @override
  Future<void> unblockAndroidApp({required String packageName}) async {
    _requirePackageName(packageName);
    await methodChannel.invokeMethod<void>('unblockApp', {
      'packageName': packageName.trim(),
    });
  }

  @override
  Future<void> blockAllAndroidApps() async {
    await methodChannel.invokeMethod<void>('blockAllApps');
  }

  @override
  Future<void> unblockAllAndroidApps() async {
    await methodChannel.invokeMethod<void>('unblockAllApps');
  }

  @override
  Future<void> blockAndroidApps() => blockAllAndroidApps();

  @override
  Future<void> unblockAndroidApps() => unblockAllAndroidApps();

  @override
  Future<List<String>> getBlockedAndroidApps() async {
    final packages = await methodChannel.invokeListMethod<String>(
      'getBlockedApps',
    );
    return packages ?? <String>[];
  }

  @override
  Future<bool> isAndroidBlockingActive() async {
    final active = await methodChannel.invokeMethod<bool>('isBlockingActive');
    return active ?? false;
  }

  @override
  Future<Map<String, dynamic>> getPlatformCapabilities() async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getCapabilities',
    );
    if (result == null) {
      return <String, dynamic>{};
    }

    return _stringKeyed(result);
  }

  @override
  Future<void> setAndroidEnterpriseModeEnabled({required bool enabled}) async {
    await methodChannel.invokeMethod<void>('setEnterpriseMode', {
      'enabled': enabled,
    });
  }

  @override
  Future<bool> isAndroidEnterpriseModeEnabled() async {
    final enabled = await methodChannel.invokeMethod<bool>(
      'isEnterpriseModeEnabled',
    );
    return enabled ?? false;
  }

  @override
  Stream<Map<String, dynamic>> getEventStream() => _events;
}
