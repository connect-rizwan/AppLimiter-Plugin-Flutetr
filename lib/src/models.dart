import 'package:flutter/foundation.dart';

/// A permission the plugin needs to block apps.
enum AppPermission {
  /// Android: display over other apps (`SYSTEM_ALERT_WINDOW`). Required.
  overlay,

  /// Android: usage access, used to detect the foreground app. Required.
  usageAccess,

  /// Android 13+: post notifications. Optional; without it the blocking
  /// service still runs but its notification is hidden.
  notifications,

  /// iOS: Screen Time (Family Controls) authorization. Required.
  screenTime,
}

/// Screen Time authorization status on iOS.
enum IosAuthorizationStatus {
  /// The user has not been asked yet.
  notDetermined,

  /// The user declined. iOS will not prompt again; the user has to enable it
  /// in the Settings app.
  denied,

  /// Access granted.
  approved;

  static IosAuthorizationStatus parse(String? value) {
    return IosAuthorizationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => IosAuthorizationStatus.notDetermined,
    );
  }
}

/// Which permissions are granted.
@immutable
class PermissionStatus {
  const PermissionStatus({
    this.missing = const <AppPermission>{},
    this.optionalMissing = const <AppPermission>{},
    this.iosAuthorizationStatus,
  });

  /// Required permissions that are not granted yet. Blocking fails with
  /// [AppLimiterErrorCode.permissionDenied] until this is empty.
  final Set<AppPermission> missing;

  /// Optional permissions that are not granted.
  final Set<AppPermission> optionalMissing;

  /// Detailed authorization status on iOS, null on Android.
  final IosAuthorizationStatus? iosAuthorizationStatus;

  /// True when every required permission is granted.
  bool get isGranted => missing.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is PermissionStatus &&
      setEquals(other.missing, missing) &&
      setEquals(other.optionalMissing, optionalMissing) &&
      other.iosAuthorizationStatus == iosAuthorizationStatus;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(missing),
    Object.hashAllUnordered(optionalMissing),
    iosAuthorizationStatus,
  );

  @override
  String toString() =>
      'PermissionStatus(missing: $missing, optionalMissing: $optionalMissing'
      '${iosAuthorizationStatus == null ? '' : ', ios: ${iosAuthorizationStatus!.name}'})';
}

/// What is currently blocked.
@immutable
class BlockingState {
  const BlockingState({
    required this.isActive,
    this.blockAll = false,
    this.blockedPackages = const <String>[],
    this.iosSelectedApplicationCount = 0,
    this.iosSelectedCategoryCount = 0,
    this.iosSelectedWebDomainCount = 0,
  });

  /// True while blocking is being enforced.
  final bool isActive;

  /// Android: every app with a launcher icon is blocked.
  final bool blockAll;

  /// Android: individually blocked packages.
  final List<String> blockedPackages;

  /// iOS: number of apps in the saved picker selection.
  final int iosSelectedApplicationCount;

  /// iOS: number of categories in the saved picker selection.
  final int iosSelectedCategoryCount;

  /// iOS: number of web domains in the saved picker selection.
  final int iosSelectedWebDomainCount;

  /// iOS: true when the picker selection contains anything.
  bool get hasIosSelection =>
      iosSelectedApplicationCount +
          iosSelectedCategoryCount +
          iosSelectedWebDomainCount >
      0;

  @override
  bool operator ==(Object other) =>
      other is BlockingState &&
      other.isActive == isActive &&
      other.blockAll == blockAll &&
      listEquals(other.blockedPackages, blockedPackages) &&
      other.iosSelectedApplicationCount == iosSelectedApplicationCount &&
      other.iosSelectedCategoryCount == iosSelectedCategoryCount &&
      other.iosSelectedWebDomainCount == iosSelectedWebDomainCount;

  @override
  int get hashCode => Object.hash(
    isActive,
    blockAll,
    Object.hashAll(blockedPackages),
    iosSelectedApplicationCount,
    iosSelectedCategoryCount,
    iosSelectedWebDomainCount,
  );

  @override
  String toString() =>
      'BlockingState(isActive: $isActive, blockAll: $blockAll, '
      'blockedPackages: $blockedPackages, iosSelection: '
      '$iosSelectedApplicationCount apps / $iosSelectedCategoryCount categories / '
      '$iosSelectedWebDomainCount domains)';
}

/// Play Store category of an installed Android app (Android 8+).
enum AppCategory {
  game,
  audio,
  video,
  image,
  social,
  news,
  maps,
  productivity,
  accessibility,
  undefined;

  static AppCategory parse(String? value) {
    return AppCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => AppCategory.undefined,
    );
  }
}

/// An app installed on an Android device that has a launcher icon.
@immutable
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.name,
    this.isSystemApp = false,
    this.category = AppCategory.undefined,
    this.icon,
  });

  /// Package name, e.g. `com.google.android.youtube`. Pass it to
  /// `AndroidAppLimiter.blockApp`.
  final String packageName;

  /// User-visible app name.
  final String name;

  /// True for preinstalled system apps (including updated ones).
  final bool isSystemApp;

  final AppCategory category;

  /// PNG-encoded icon, only set when requested with `includeIcons: true`.
  /// Show it with `Image.memory(app.icon!)`.
  final Uint8List? icon;

  factory InstalledApp.fromMap(Map<String, dynamic> map) {
    final icon = map['icon'];
    return InstalledApp(
      packageName: map['packageName'] as String,
      name: map['name'] as String? ?? map['packageName'] as String,
      isSystemApp: map['isSystemApp'] as bool? ?? false,
      category: AppCategory.parse(map['category'] as String?),
      icon: icon is Uint8List ? icon : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InstalledApp &&
      other.packageName == packageName &&
      other.name == name &&
      other.isSystemApp == isSystemApp &&
      other.category == category &&
      listEquals(other.icon, icon);

  @override
  int get hashCode => Object.hash(packageName, name, isSystemApp, category);

  @override
  String toString() => 'InstalledApp($packageName, $name)';
}

/// Daily window for iOS DeviceActivity monitoring.
///
/// Only takes effect when the host app ships a `DeviceActivityMonitor`
/// extension.
@immutable
class IosSchedule {
  const IosSchedule({
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    this.repeats = true,
    this.thresholdMinutes = 1,
  }) : assert(startHour >= 0 && startHour < 24),
       assert(endHour >= 0 && endHour < 24),
       assert(startMinute >= 0 && startMinute < 60),
       assert(endMinute >= 0 && endMinute < 60),
       assert(thresholdMinutes >= 1);

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool repeats;

  /// Usage threshold that triggers the monitor's event.
  final int thresholdMinutes;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'startHour': startHour,
    'startMinute': startMinute,
    'endHour': endHour,
    'endMinute': endMinute,
    'repeats': repeats,
    'thresholdMinutes': thresholdMinutes,
  };
}

/// Kinds of [AppLimiterEvent].
enum AppLimiterEventType {
  /// Blocking was turned on/off or its targets changed.
  blockingStateChanged,

  /// Android stopped blocking on its own, e.g. a permission was revoked.
  /// See `payload['reason']`.
  blockingStopped,

  /// A permission request finished (Android) or Screen Time authorization
  /// changed (iOS).
  permissionChanged,

  /// iOS picker selection was saved.
  selectionChanged,

  /// iOS schedule was configured.
  scheduleChanged,

  /// iOS picker was shown.
  pickerPresented,

  /// An event this version of the plugin does not know.
  unknown,
}

/// Event emitted by the native side.
@immutable
class AppLimiterEvent {
  const AppLimiterEvent({
    required this.name,
    required this.type,
    this.payload = const <String, dynamic>{},
    required this.timestamp,
  });

  static const Map<String, AppLimiterEventType> _types = {
    'android_blocking_state_changed': AppLimiterEventType.blockingStateChanged,
    'ios_blocking_state_changed': AppLimiterEventType.blockingStateChanged,
    'android_blocking_stopped': AppLimiterEventType.blockingStopped,
    'ios_permission_status': AppLimiterEventType.permissionChanged,
    'android_permission_status': AppLimiterEventType.permissionChanged,
    'ios_selection_updated': AppLimiterEventType.selectionChanged,
    'ios_schedule_configured': AppLimiterEventType.scheduleChanged,
    'ios_picker_presented': AppLimiterEventType.pickerPresented,
  };

  /// Raw native event name, e.g. `android_blocking_state_changed`.
  final String name;
  final AppLimiterEventType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  factory AppLimiterEvent.fromMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'unknown';
    final payload = map['payload'];
    final seconds = map['timestamp'];
    return AppLimiterEvent(
      name: name,
      type: _types[name] ?? AppLimiterEventType.unknown,
      payload: payload is Map<String, dynamic>
          ? payload
          : <String, dynamic>{if (payload != null) 'value': payload},
      timestamp: seconds is int
          ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
          : DateTime.now(),
    );
  }

  /// The raw map form, as emitted by 0.x versions of the plugin.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'payload': payload,
    'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
  };

  @override
  String toString() => 'AppLimiterEvent($name, $payload)';
}
