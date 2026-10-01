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

  test('BlockScreenConfig defaults', () {
    expect(const BlockScreenConfig().toMap(), {
      'title': null,
      'message': null,
      'footer': null,
      'backgroundColor': null,
      'textColor': null,
      'icon': null,
      'showIcon': true,
      'buttonLabel': null,
      'buttonAction': 'closeApp',
    });
  });

  group('BlockSchedule.isActiveAt', () {
    // 2026-10-05 is a Monday.
    DateTime at(int day, int hour, [int minute = 0]) =>
        DateTime(2026, 10, 4 + day, hour, minute);

    test('daytime window', () {
      const work = BlockSchedule(
        id: 'work',
        packages: ['a'],
        start: DailyTime(9),
        end: DailyTime(17),
        weekdays: BlockSchedule.workdays,
      );
      expect(at(1, 0).weekday, DateTime.monday);
      expect(work.isActiveAt(at(1, 9)), isTrue);
      expect(work.isActiveAt(at(5, 16, 59)), isTrue);
      expect(work.isActiveAt(at(1, 17)), isFalse);
      expect(work.isActiveAt(at(6, 12)), isFalse);
    });

    test('overnight window continues into the next day', () {
      const friday = BlockSchedule(
        id: 'night',
        allApps: true,
        start: DailyTime(22),
        end: DailyTime(7),
        weekdays: {DateTime.friday},
      );
      expect(friday.isActiveAt(at(5, 23)), isTrue);
      expect(friday.isActiveAt(at(6, 6, 59)), isTrue);
      expect(friday.isActiveAt(at(6, 7)), isFalse);
      expect(friday.isActiveAt(at(6, 23)), isFalse);
    });

    test('Sunday night wraps to Monday', () {
      const sunday = BlockSchedule(
        id: 'night',
        allApps: true,
        start: DailyTime(23),
        end: DailyTime(6),
        weekdays: {DateTime.sunday},
      );
      expect(sunday.isActiveAt(at(1, 2)), isTrue);
    });

    test('equal start and end blocks the whole day', () {
      const allDay = BlockSchedule(
        id: 'd',
        packages: ['a'],
        start: DailyTime(0),
        end: DailyTime(0),
        weekdays: {DateTime.wednesday},
      );
      expect(allDay.isActiveAt(at(3, 0)), isTrue);
      expect(allDay.isActiveAt(at(3, 23, 59)), isTrue);
      expect(allDay.isActiveAt(at(4, 0)), isFalse);
    });
  });

  test('BlockSchedule map round-trip', () {
    const schedule = BlockSchedule(
      id: 'x',
      packages: ['a', 'b'],
      start: DailyTime(8, 15),
      end: DailyTime(12, 45),
      weekdays: {DateTime.saturday, DateTime.sunday},
    );
    expect(BlockSchedule.fromMap(schedule.toMap()), schedule);
    expect(schedule.toMap()['weekdays'], [6, 7]);
  });

  test('DailyTime', () {
    expect(const DailyTime(7, 5).toString(), '07:05');
    expect(const DailyTime.fromMinuteOfDay(1439), const DailyTime(23, 59));
    expect(() => DailyTime(24), throwsAssertionError);
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
