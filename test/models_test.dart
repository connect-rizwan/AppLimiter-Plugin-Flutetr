import 'package:app_limiter/app_limiter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PermissionStatus.isGranted ignores optional permissions', () {
    const status = PermissionStatus(
      optionalMissing: {AppPermission.notifications},
    );
    expect(status.isGranted, isTrue);
    expect(
      const PermissionStatus(missing: {AppPermission.overlay}).isGranted,
      isFalse,
    );
  });

  test('PermissionStatus equality ignores set order', () {
    expect(
      const PermissionStatus(
        missing: {AppPermission.overlay, AppPermission.usageAccess},
      ),
      const PermissionStatus(
        missing: {AppPermission.usageAccess, AppPermission.overlay},
      ),
    );
  });

  test('enum parsing falls back for unknown values', () {
    expect(
      IosAuthorizationStatus.parse('approved'),
      IosAuthorizationStatus.approved,
    );
    expect(
      IosAuthorizationStatus.parse('bogus'),
      IosAuthorizationStatus.notDetermined,
    );
    expect(AppCategory.parse('social'), AppCategory.social);
    expect(AppCategory.parse(null), AppCategory.undefined);
  });

  test('every error code round-trips through its native code', () {
    for (final code in AppLimiterErrorCode.values) {
      expect(AppLimiterErrorCode.fromNative(code.nativeCode), code);
    }
  });

  test('AppLimiterException.fromPlatformException', () {
    final e = AppLimiterException.fromPlatformException(
      PlatformException(code: 'NO_SELECTION'),
    );
    expect(e.code, AppLimiterErrorCode.noSelection);
    expect(e.message, 'NO_SELECTION');
    expect(e.toString(), contains('noSelection'));
  });

  test('IosSchedule validates its fields', () {
    expect(() => IosSchedule(startHour: 24, endHour: 1), throwsAssertionError);
    expect(
      () => IosSchedule(startHour: 1, endHour: 2, thresholdMinutes: 0),
      throwsAssertionError,
    );
  });

  test('AppLimiterEvent.toMap round-trips', () {
    final event = AppLimiterEvent.fromMap({
      'name': 'ios_selection_updated',
      'payload': {'applicationCount': 2},
      'timestamp': 1700000000,
    });
    expect(event.type, AppLimiterEventType.selectionChanged);
    expect(AppLimiterEvent.fromMap(event.toMap()).toMap(), event.toMap());
  });
}
