import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_limiter_platform_interface.dart';
import 'src/exception.dart';
import 'src/models.dart';

/// An implementation of [AppLimiterPlatform] that uses method channels.
class MethodChannelAppLimiter extends AppLimiterPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('app_limiter');
  final eventChannel = const EventChannel('app_limiter/events');

  late final Stream<AppLimiterEvent> _events = eventChannel
      .receiveBroadcastStream()
      .map((dynamic event) {
        if (event is Map) {
          return AppLimiterEvent.fromMap(_stringKeyed(event));
        }
        return AppLimiterEvent.fromMap(<String, dynamic>{'payload': event});
      });

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> map) {
    return map.map(
      (dynamic key, dynamic value) =>
          MapEntry(key.toString(), value is Map ? _stringKeyed(value) : value),
    );
  }

  static AppLimiterException _unsupportedPlatform() => AppLimiterException(
    AppLimiterErrorCode.unsupported,
    'app_limiter does not support ${defaultTargetPlatform.name}.',
  );

  /// Invokes [method], converting native failures to [AppLimiterException].
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw AppLimiterException.fromPlatformException(e);
    } on MissingPluginException {
      throw AppLimiterException(
        AppLimiterErrorCode.unsupported,
        '$method is not available on ${defaultTargetPlatform.name}.',
      );
    }
  }

  Future<Map<String, dynamic>> _invokeMap(
    String method, [
    Object? arguments,
  ]) async {
    final result = await _invoke<Map<dynamic, dynamic>>(method, arguments);
    return result == null ? <String, dynamic>{} : _stringKeyed(result);
  }

  static PermissionStatus _androidPermissionStatus(Map<String, dynamic> map) {
    return PermissionStatus(
      missing: {
        if (map['overlay'] != true) AppPermission.overlay,
        if (map['usageAccess'] != true) AppPermission.usageAccess,
      },
      optionalMissing: {
        if (map['notifications'] == false) AppPermission.notifications,
      },
    );
  }

  static PermissionStatus _iosPermissionStatus(IosAuthorizationStatus status) {
    return PermissionStatus(
      missing: {
        if (status != IosAuthorizationStatus.approved) AppPermission.screenTime,
      },
      iosAuthorizationStatus: status,
    );
  }

  // Common

  @override
  Future<String?> getPlatformVersion() => _invoke<String>('getPlatformVersion');

  @override
  Future<PermissionStatus> getPermissionStatus() async {
    if (_isAndroid) {
      return _androidPermissionStatus(await _invokeMap('getPermissionStatus'));
    }
    if (_isIOS) {
      final status = await _invoke<String>('getAuthorizationStatus');
      return _iosPermissionStatus(IosAuthorizationStatus.parse(status));
    }
    throw _unsupportedPlatform();
  }

  @override
  Future<PermissionStatus> requestPermission([
    AppPermission? permission,
  ]) async {
    if (_isAndroid) {
      if (permission == AppPermission.screenTime) {
        return getPermissionStatus();
      }
      return _androidPermissionStatus(
        await _invokeMap('requestPermission', {'permission': permission?.name}),
      );
    }
    if (_isIOS) {
      if (permission == null || permission == AppPermission.screenTime) {
        await _invoke<bool>('requestPermission');
      }
      return getPermissionStatus();
    }
    throw _unsupportedPlatform();
  }

  @override
  Future<BlockingState> getBlockingState() async {
    if (!_isAndroid && !_isIOS) throw _unsupportedPlatform();
    final map = await _invokeMap('getBlockingState');
    return BlockingState(
      isActive: map['active'] == true,
      blockAll: map['blockAll'] == true,
      blockedPackages: List<String>.from(
        map['blockedPackages'] as List? ?? const [],
      ),
      iosSelectedApplicationCount: map['applicationCount'] as int? ?? 0,
      iosSelectedCategoryCount: map['categoryCount'] as int? ?? 0,
      iosSelectedWebDomainCount: map['webDomainCount'] as int? ?? 0,
    );
  }

  @override
  Future<void> unblockAll() async {
    if (_isAndroid) return _invoke<void>('unblockAllApps');
    if (_isIOS) return _invoke<void>('unblockIOSApps');
    throw _unsupportedPlatform();
  }

  @override
  Stream<AppLimiterEvent> get events => _events;

  @override
  Future<Map<String, dynamic>> getCapabilities() =>
      _invokeMap('getCapabilities');

  // Android

  @override
  Future<void> androidBlockApps(List<String> packageNames) =>
      _invoke<void>('blockApps', {'packageNames': packageNames});

  @override
  Future<void> androidUnblockApps(List<String> packageNames) =>
      _invoke<void>('unblockApps', {'packageNames': packageNames});

  @override
  Future<void> androidBlockAllApps() => _invoke<void>('blockAllApps');

  @override
  Future<List<InstalledApp>> androidGetInstalledApps({
    bool includeIcons = false,
    bool includeSystemApps = true,
    int iconSize = 96,
  }) async {
    final apps = await _invoke<List<dynamic>>('getInstalledApps', {
      'includeIcons': includeIcons,
      'includeSystemApps': includeSystemApps,
      'iconSize': iconSize,
    });
    return (apps ?? const [])
        .whereType<Map>()
        .map((app) => InstalledApp.fromMap(_stringKeyed(app)))
        .toList();
  }

  @override
  Future<bool> androidIsEnterpriseCapable() async =>
      await _invoke<bool>('isEnterpriseCapable') ?? false;

  @override
  Future<void> androidSetEnterpriseModeEnabled(bool enabled) =>
      _invoke<void>('setEnterpriseMode', {'enabled': enabled});

  @override
  Future<bool> androidIsEnterpriseModeEnabled() async =>
      await _invoke<bool>('isEnterpriseModeEnabled') ?? false;

  // iOS

  @override
  Future<bool> iosShowAppPicker() async =>
      await _invoke<bool>('showAppPicker') ?? false;

  @override
  Future<void> iosBlockSelectedApps() => _invoke<void>('blockIOSApps');

  @override
  Future<void> iosShowAppPickerAndBlock({Map<String, dynamic>? schedule}) =>
      _invoke<void>('selectAndConfigureIosAppRestrictions', {
        'schedule': schedule,
      });

  @override
  Future<void> iosConfigureSchedule(Map<String, dynamic> schedule) =>
      _invoke<void>('configureIosSchedule', {'schedule': schedule});
}
