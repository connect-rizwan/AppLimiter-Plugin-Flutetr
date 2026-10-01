import 'package:flutter/services.dart';

/// Why an [AppLimiterException] was thrown.
enum AppLimiterErrorCode {
  /// A required permission is missing. Call `requestPermission()`.
  permissionDenied('PERMISSION_DENIED'),

  /// iOS: `blockSelectedApps()` was called before choosing apps.
  noSelection('NO_SELECTION'),

  /// An argument was invalid, e.g. an empty package name.
  invalidArgument('INVALID_ARGUMENT'),

  /// iOS: no view controller was available to present the picker.
  noViewController('NO_VIEW_CONTROLLER'),

  /// Android: the call needs a foreground activity.
  noActivity('NO_ACTIVITY'),

  /// Android: another permission request is still waiting for the user.
  requestInProgress('REQUEST_IN_PROGRESS'),

  /// iOS: the Screen Time authorization request failed (restricted device,
  /// unsupported account, no network, ...).
  authorizationFailed('AUTH_ERROR'),

  /// Android: device owner (enterprise) mode is not available.
  enterpriseNotAvailable('ENTERPRISE_NOT_AVAILABLE'),

  /// Android: suspending or unsuspending packages failed.
  enterpriseActionFailed('ENTERPRISE_ACTION_FAILED'),

  /// iOS: an app extension or the App Group this feature needs is not set
  /// up. See `ios/extension_templates/README.md` and `ios.getExtensionStatus()`.
  extensionMissing('EXTENSION_MISSING'),

  /// The method is not available on this platform or OS version.
  unsupported('UNSUPPORTED'),

  /// Any other native error.
  unknown('UNKNOWN');

  const AppLimiterErrorCode(this.nativeCode);

  /// Code used by the native side.
  final String nativeCode;

  static AppLimiterErrorCode fromNative(String code) {
    return AppLimiterErrorCode.values.firstWhere(
      (value) => value.nativeCode == code,
      orElse: () => AppLimiterErrorCode.unknown,
    );
  }
}

/// Error thrown by every `app_limiter` API.
class AppLimiterException implements Exception {
  const AppLimiterException(this.code, this.message, {this.details});

  factory AppLimiterException.fromPlatformException(PlatformException e) {
    return AppLimiterException(
      AppLimiterErrorCode.fromNative(e.code),
      e.message ?? e.code,
      details: e.details,
    );
  }

  final AppLimiterErrorCode code;
  final String message;

  /// Extra native information, e.g. the packages that failed to suspend.
  final Object? details;

  @override
  String toString() => 'AppLimiterException(${code.name}): $message';
}
