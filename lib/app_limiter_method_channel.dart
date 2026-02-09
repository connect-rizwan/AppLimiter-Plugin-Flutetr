import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_limiter_platform_interface.dart';

/// An implementation of [AppLimiterPlatform] that uses method channels.
class MethodChannelAppLimiter extends AppLimiterPlatform {
  /// The method channel used to interact with the native platform.
  final methodChannel = const MethodChannel('app_limiter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  /// iOS-specific implementation for blocking and unblocking apps
  @override
  Future<void> blockAndUnblockIOSApp() async {
    try {
      await methodChannel.invokeMethod('blockApp');
    } on PlatformException catch (e) {
      debugPrint('Failed to block/Unbloc iOS app: ${e.message}');
    }
  }

  /// Requests iOS permissions through the native implementation
  @override
  Future<bool> requestIosPermission() async {
    try {
      final result = await methodChannel.invokeMethod('requestPermission');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to get status: ${e.message}');
      return false;
    }
  }

  /// Checks Android permission status through the native implementation
  @override
  Future<bool> isAndroidPermissionAllowed() async {
    try {
      final result = await methodChannel.invokeMethod('checkPermission');
      if (result == "approved") {
        return true;
      } else {
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to get status: ${e.message}');
      return false;
    }
  }

  /// Requests Android permissions through the native implementation
  @override
  Future<void> requestAndroidPermission() async {
    try {
      await methodChannel.invokeMethod('requestAuthorization');
    } on PlatformException catch (e) {
      debugPrint('Failed to request android permission app: ${e.message}');
    }
  }

  /// Android-specific implementation for blocking apps
  @override
  Future<void> blockAndroidApps() async {
    try {
      await methodChannel.invokeMethod('blockApp');
    } on PlatformException catch (e) {
      debugPrint('Failed to block Android app: ${e.message}');
    }
  }

  /// Android-specific implementation for unblocking apps
  @override
  Future<void> unblockAndroidApps() async {
    try {
      await methodChannel.invokeMethod('unblockApp');
    } on PlatformException catch (e) {
      debugPrint('Failed to unblock Android app: ${e.message}');
    }
  }

  // iOS App Blocking methods
  /// Shows the app picker UI for selecting apps to block (iOS only)
  @override
  Future<void> showIOSAppPicker() async {
    try {
      await methodChannel.invokeMethod('showAppPicker');
    } on PlatformException catch (e) {
      debugPrint('Failed to show app picker: ${e.message}');
      rethrow;
    }
  }

  /// Blocks the previously selected apps (iOS only)
  @override
  Future<void> blockIOSApps() async {
    try {
      await methodChannel.invokeMethod('blockIOSApps');
    } on PlatformException catch (e) {
      debugPrint('Failed to block iOS apps: ${e.message}');
      rethrow;
    }
  }

  /// Unblocks all apps (iOS only)
  @override
  Future<void> unblockIOSApps() async {
    try {
      await methodChannel.invokeMethod('unblockIOSApps');
    } on PlatformException catch (e) {
      debugPrint('Failed to unblock iOS apps: ${e.message}');
      rethrow;
    }
  }

  /// Checks if apps are currently blocked (iOS only)
  @override
  Future<bool> isIOSAppsBlocked() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('isIOSAppsBlocked');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to check iOS apps blocked status: ${e.message}');
      return false;
    }
  }

  /// Gets the current Screen Time authorization status (iOS only)
  /// Returns one of: "notDetermined", "authorized", "denied"
  @override
  Future<String> getIOSAuthorizationStatus() async {
    try {
      final result = await methodChannel.invokeMethod<String>(
        'getAuthorizationStatus',
      );
      return result ?? 'notDetermined';
    } on PlatformException catch (e) {
      debugPrint('Failed to get authorization status: ${e.message}');
      return 'notDetermined';
    }
  }
}
