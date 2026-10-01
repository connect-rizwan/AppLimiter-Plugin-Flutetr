import 'package:app_limiter/app_limiter.dart';
import 'package:app_limiter/app_limiter_method_channel.dart';
import 'package:app_limiter/app_limiter_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records every call so tests can assert the facade forwards correctly.
class FakeAppLimiterPlatform extends AppLimiterPlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = <String>[];
  final List<Object?> arguments = <Object?>[];

  PermissionStatus permissionStatus = const PermissionStatus();
  BlockingState blockingState = const BlockingState(
    isActive: true,
    blockedPackages: ['a.b'],
  );

  void _record(String name, [Object? argument]) {
    calls.add(name);
    arguments.add(argument);
  }

  @override
  Future<String?> getPlatformVersion() async {
    _record('getPlatformVersion');
    return '42';
  }

  @override
  Future<PermissionStatus> getPermissionStatus() async {
    _record('getPermissionStatus');
    return permissionStatus;
  }

  @override
  Future<PermissionStatus> requestPermission([
    AppPermission? permission,
  ]) async {
    _record('requestPermission', permission);
    return permissionStatus;
  }

  @override
  Future<BlockingState> getBlockingState() async {
    _record('getBlockingState');
    return blockingState;
  }

  @override
  Future<void> unblockAll() async => _record('unblockAll');

  @override
  Stream<AppLimiterEvent> get events => Stream.value(
    AppLimiterEvent(
      name: 'x',
      type: AppLimiterEventType.unknown,
      timestamp: DateTime(2026),
    ),
  );

  @override
  Future<Map<String, dynamic>> getCapabilities() async {
    _record('getCapabilities');
    return {'platform': 'android'};
  }

  @override
  Future<void> androidBlockApps(
    List<String> packageNames, {
    Duration? duration,
  }) async => _record('androidBlockApps', [packageNames, duration]);

  @override
  Future<void> androidUnblockApps(List<String> packageNames) async =>
      _record('androidUnblockApps', packageNames);

  @override
  Future<void> androidBlockAllApps({
    List<String> except = const [],
    Duration? duration,
  }) async => _record('androidBlockAllApps', [except, duration]);

  List<BlockSchedule> schedules = const [];

  @override
  Future<void> androidSetSchedule(BlockSchedule schedule) async =>
      _record('androidSetSchedule', schedule);

  @override
  Future<void> androidRemoveSchedule(String id) async =>
      _record('androidRemoveSchedule', id);

  @override
  Future<List<BlockSchedule>> androidGetSchedules() async {
    _record('androidGetSchedules');
    return schedules;
  }

  @override
  Future<void> androidSetBlockScreen(BlockScreenConfig config) async =>
      _record('androidSetBlockScreen', config);

  @override
  Future<void> androidSetNotification({String? title, String? text}) async =>
      _record('androidSetNotification', [title, text]);

  @override
  Future<List<InstalledApp>> androidGetInstalledApps({
    bool includeIcons = false,
    bool includeSystemApps = true,
    int iconSize = 96,
  }) async {
    _record('androidGetInstalledApps', [
      includeIcons,
      includeSystemApps,
      iconSize,
    ]);
    return const [InstalledApp(packageName: 'a.b', name: 'AB')];
  }

  @override
  Future<bool> androidIsEnterpriseCapable() async {
    _record('androidIsEnterpriseCapable');
    return true;
  }

  @override
  Future<void> androidSetEnterpriseModeEnabled(bool enabled) async =>
      _record('androidSetEnterpriseModeEnabled', enabled);

  @override
  Future<bool> androidIsEnterpriseModeEnabled() async {
    _record('androidIsEnterpriseModeEnabled');
    return false;
  }

  @override
  Future<bool> iosShowAppPicker() async {
    _record('iosShowAppPicker');
    return true;
  }

  @override
  Future<void> iosBlockSelectedApps({Duration? duration}) async =>
      _record('iosBlockSelectedApps', duration);

  @override
  Future<IosExtensionStatus> iosGetExtensionStatus() async {
    _record('iosGetExtensionStatus');
    return const IosExtensionStatus(appGroup: 'group.test');
  }

  @override
  Future<void> iosSetShield(IosShieldConfig config) async =>
      _record('iosSetShield', config);

  @override
  Future<void> iosSetSchedule(IosBlockSchedule schedule) async =>
      _record('iosSetSchedule', schedule);

  @override
  Future<void> iosRemoveSchedule(String id) async =>
      _record('iosRemoveSchedule', id);

  @override
  Future<List<IosBlockSchedule>> iosGetSchedules() async {
    _record('iosGetSchedules');
    return const [];
  }

  @override
  Future<void> iosShowAppPickerAndBlock({
    Map<String, dynamic>? schedule,
  }) async => _record('iosShowAppPickerAndBlock', schedule);

  @override
  Future<void> iosConfigureSchedule(Map<String, dynamic> schedule) async =>
      _record('iosConfigureSchedule', schedule);
}

/// Uses only the base-class defaults.
class BarePlatform extends AppLimiterPlatform with MockPlatformInterfaceMixin {}

Matcher throwsAppLimiter(AppLimiterErrorCode code) =>
    throwsA(isA<AppLimiterException>().having((e) => e.code, 'code', code));

void main() {
  final AppLimiterPlatform initialPlatform = AppLimiterPlatform.instance;
  late FakeAppLimiterPlatform fake;
  final limiter = AppLimiter();

  setUp(() {
    fake = FakeAppLimiterPlatform();
    AppLimiterPlatform.instance = fake;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('$MethodChannelAppLimiter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppLimiter>());
  });

  test('isSupported', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppLimiter.isSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppLimiter.isSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(AppLimiter.isSupported, isFalse);
  });

  group('common API forwards to the platform', () {
    test('calls', () async {
      expect(await limiter.getPlatformVersion(), '42');
      expect(await limiter.getPermissionStatus(), const PermissionStatus());
      await limiter.requestPermission(AppPermission.usageAccess);
      expect((await limiter.getBlockingState()).blockedPackages, ['a.b']);
      await limiter.unblockAll();
      expect((await limiter.events.first).name, 'x');

      expect(fake.calls, [
        'getPlatformVersion',
        'getPermissionStatus',
        'requestPermission',
        'getBlockingState',
        'unblockAll',
      ]);
      expect(fake.arguments[2], AppPermission.usageAccess);
    });
  });

  group('android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('forwards calls with trimmed package names', () async {
      await limiter.android.blockApp(' a.b ');
      await limiter.android.blockApps(['c.d', 'e.f']);
      await limiter.android.unblockApp('a.b');
      await limiter.android.unblockApps(['c.d']);
      await limiter.android.blockAllApps();
      final apps = await limiter.android.getInstalledApps(includeIcons: true);
      expect(await limiter.android.isEnterpriseCapable(), isTrue);
      await limiter.android.setEnterpriseModeEnabled(true);
      expect(await limiter.android.isEnterpriseModeEnabled(), isFalse);

      expect(fake.calls, [
        'androidBlockApps',
        'androidBlockApps',
        'androidUnblockApps',
        'androidUnblockApps',
        'androidBlockAllApps',
        'androidGetInstalledApps',
        'androidIsEnterpriseCapable',
        'androidSetEnterpriseModeEnabled',
        'androidIsEnterpriseModeEnabled',
      ]);
      expect(fake.arguments[0], [
        ['a.b'],
        null,
      ]);
      expect(fake.arguments[1], [
        ['c.d', 'e.f'],
        null,
      ]);
      expect(fake.arguments[5], [true, true, 96]);
      expect(apps.single.packageName, 'a.b');
    });

    test('blockAllApps trims and validates the allowlist', () async {
      await limiter.android.blockAllApps(except: [' com.whatsapp ']);
      expect(fake.arguments.single, [
        ['com.whatsapp'],
        null,
      ]);
      expect(
        () => limiter.android.blockAllApps(except: ['']),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
    });

    test('block screen and notification configuration', () async {
      const config = BlockScreenConfig(title: 'Focus');
      await limiter.android.setBlockScreen(config);
      await limiter.android.setNotification(title: 'On', text: 'Blocking');
      expect(fake.calls, ['androidSetBlockScreen', 'androidSetNotification']);
      expect(fake.arguments[0], same(config));
      expect(fake.arguments[1], ['On', 'Blocking']);
    });

    test('durations are forwarded and validated', () async {
      await limiter.android.blockApp(
        'a.b',
        duration: const Duration(minutes: 30),
      );
      await limiter.android.blockAllApps(duration: const Duration(hours: 1));
      expect(fake.arguments[0], [
        ['a.b'],
        const Duration(minutes: 30),
      ]);
      expect(fake.arguments[1], [<String>[], const Duration(hours: 1)]);

      expect(
        () => limiter.android.blockApp('a.b', duration: Duration.zero),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
      expect(
        () =>
            limiter.android.blockAllApps(duration: const Duration(seconds: -1)),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
      expect(fake.calls, hasLength(2));
    });

    test('schedules are forwarded', () async {
      const schedule = BlockSchedule(
        id: 'night',
        packages: ['com.game'],
        start: DailyTime(22),
        end: DailyTime(7),
      );
      fake.schedules = const [schedule];

      await limiter.android.setSchedule(schedule);
      await limiter.android.removeSchedule('night');
      expect(await limiter.android.getSchedules(), [schedule]);

      expect(fake.calls, [
        'androidSetSchedule',
        'androidRemoveSchedule',
        'androidGetSchedules',
      ]);
      expect(fake.arguments[0], same(schedule));
      expect(fake.arguments[1], 'night');
    });

    test('invalid schedules are rejected without calling native', () {
      for (final schedule in const [
        BlockSchedule(
          id: ' ',
          packages: ['a.b'],
          start: DailyTime(1),
          end: DailyTime(2),
        ),
        BlockSchedule(id: 'x', start: DailyTime(1), end: DailyTime(2)),
        BlockSchedule(
          id: 'x',
          packages: ['a.b'],
          start: DailyTime(1),
          end: DailyTime(2),
          weekdays: {},
        ),
        BlockSchedule(
          id: 'x',
          packages: ['a.b'],
          start: DailyTime(1),
          end: DailyTime(2),
          weekdays: {0},
        ),
        BlockSchedule(
          id: 'x',
          packages: [''],
          start: DailyTime(1),
          end: DailyTime(2),
        ),
      ]) {
        expect(
          () => limiter.android.setSchedule(schedule),
          throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
          reason: schedule.toString(),
        );
      }
      expect(fake.calls, isEmpty);
    });

    test('rejects empty package names without calling native', () {
      expect(
        () => limiter.android.blockApp(' '),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
      expect(
        () => limiter.android.unblockApps(['a.b', '']),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
      expect(fake.calls, isEmpty);
    });

    test('empty lists are a no-op', () async {
      await limiter.android.blockApps([]);
      await limiter.android.unblockApps([]);
      expect(fake.calls, isEmpty);
    });

    test('ios APIs throw unsupported on Android', () {
      expect(
        () => limiter.ios.showAppPicker(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
      expect(
        () => limiter.ios.configureSchedule(
          const IosSchedule(startHour: 9, endHour: 17),
        ),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
      expect(fake.calls, isEmpty);
    });
  });

  group('ios', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('forwards calls and serializes the schedule', () async {
      expect(await limiter.ios.showAppPicker(), isTrue);
      await limiter.ios.blockSelectedApps();
      await limiter.ios.showAppPickerAndBlock(
        schedule: const IosSchedule(startHour: 9, endHour: 17, endMinute: 30),
      );
      await limiter.ios.configureSchedule(
        const IosSchedule(startHour: 22, endHour: 7, repeats: false),
      );

      expect(fake.calls, [
        'iosShowAppPicker',
        'iosBlockSelectedApps',
        'iosShowAppPickerAndBlock',
        'iosConfigureSchedule',
      ]);
      expect(fake.arguments[2], {
        'startHour': 9,
        'startMinute': 0,
        'endHour': 17,
        'endMinute': 30,
        'repeats': true,
        'thresholdMinutes': 1,
      });
      expect((fake.arguments[3] as Map)['repeats'], isFalse);
    });

    test('extension features are forwarded', () async {
      const shield = IosShieldConfig(title: 'Not now');
      const schedule = IosBlockSchedule(
        id: 'night',
        start: DailyTime(22),
        end: DailyTime(7),
      );

      expect((await limiter.ios.getExtensionStatus()).appGroup, 'group.test');
      await limiter.ios.setShield(shield);
      await limiter.ios.blockSelectedApps(duration: const Duration(hours: 1));
      await limiter.ios.setSchedule(schedule);
      await limiter.ios.removeSchedule('night');
      expect(await limiter.ios.getSchedules(), isEmpty);

      expect(fake.calls, [
        'iosGetExtensionStatus',
        'iosSetShield',
        'iosBlockSelectedApps',
        'iosSetSchedule',
        'iosRemoveSchedule',
        'iosGetSchedules',
      ]);
      expect(fake.arguments[1], same(shield));
      expect(fake.arguments[2], const Duration(hours: 1));
      expect(fake.arguments[3], same(schedule));
    });

    test('iOS timed blocks must last at least 15 minutes', () {
      expect(
        () => limiter.ios.blockSelectedApps(
          duration: const Duration(minutes: 14),
        ),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
      expect(fake.calls, isEmpty);
    });

    test('invalid iOS schedules are rejected', () {
      for (final schedule in const [
        IosBlockSchedule(id: '', start: DailyTime(1), end: DailyTime(2)),
        IosBlockSchedule(
          id: 'x',
          start: DailyTime(1),
          end: DailyTime(2),
          weekdays: {},
        ),
        IosBlockSchedule(
          id: 'x',
          start: DailyTime(1),
          end: DailyTime(2),
          weekdays: {8},
        ),
      ]) {
        expect(
          () => limiter.ios.setSchedule(schedule),
          throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
        );
      }
      expect(fake.calls, isEmpty);
    });

    test('android APIs throw unsupported on iOS', () {
      expect(
        () => limiter.android.blockApp('a.b'),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
      expect(
        () => limiter.android.getInstalledApps(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
      expect(fake.calls, isEmpty);
    });
  });

  group('deprecated 0.x API still works', () {
    // ignore_for_file: deprecated_member_use_from_same_package

    test('android wrappers', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      fake.permissionStatus = const PermissionStatus(
        missing: {AppPermission.overlay},
      );

      expect(await limiter.isAndroidPermissionAllowed(), isFalse);
      await limiter.requestAndroidPermission();
      await limiter.blockAndroidApp(packageName: 'a.b');
      await limiter.unblockAndroidApp(packageName: 'a.b');
      await limiter.blockAllAndroidApps();
      await limiter.unblockAllAndroidApps();
      expect(await limiter.getBlockedAndroidApps(), ['a.b']);
      expect(await limiter.isAndroidBlockingActive(), isTrue);
      await limiter.blocAndroidApp();
      await limiter.unblocAndroidApp();
      await limiter.setAndroidEnterpriseModeEnabled(enabled: true);
      expect(await limiter.isAndroidEnterpriseModeEnabled(), isFalse);
      expect(await limiter.getPlatformCapabilities(), {'platform': 'android'});

      expect(fake.calls, [
        'getPermissionStatus',
        'requestPermission',
        'androidBlockApps',
        'androidUnblockApps',
        'androidBlockAllApps',
        'unblockAll',
        'getBlockingState',
        'getBlockingState',
        'androidBlockAllApps',
        'unblockAll',
        'androidSetEnterpriseModeEnabled',
        'androidIsEnterpriseModeEnabled',
        'getCapabilities',
      ]);
    });

    test('ios wrappers', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      fake.permissionStatus = const PermissionStatus(
        iosAuthorizationStatus: IosAuthorizationStatus.approved,
      );

      await limiter.selectAndConfigureIosAppRestrictions(
        schedule: {'startHour': 8},
      );
      await limiter.configureIosSchedule({'repeats': true});
      await limiter.blockAndUnblockIOSApp();
      expect(await limiter.showIOSAppPicker(), isTrue);
      await limiter.blockIOSApps();
      await limiter.unblockIOSApps();
      expect(await limiter.isIOSAppsBlocked(), isTrue);
      expect(await limiter.getIOSAuthorizationStatus(), 'approved');
      expect(await limiter.requestIosPermission(), isTrue);

      expect(fake.calls, [
        'iosShowAppPickerAndBlock',
        'iosConfigureSchedule',
        'iosShowAppPickerAndBlock',
        'iosShowAppPicker',
        'iosBlockSelectedApps',
        'unblockAll',
        'getBlockingState',
        'getPermissionStatus',
        'requestPermission',
      ]);
      expect(fake.arguments[0], {'startHour': 8});
    });
  });

  group('AppLimiterPlatform defaults', () {
    final bare = BarePlatform();

    test('unimplemented methods throw UnimplementedError', () {
      expect(bare.getPlatformVersion, throwsUnimplementedError);
      expect(bare.getPermissionStatus, throwsUnimplementedError);
      expect(bare.androidBlockAllApps, throwsUnimplementedError);
      expect(bare.iosShowAppPicker, throwsUnimplementedError);
      expect(() => bare.events, throwsUnimplementedError);
    });
  });

  test('platform instance must extend AppLimiterPlatform', () {
    expect(
      () => AppLimiterPlatform.instance = _ImplementsPlatform(),
      throwsA(isA<AssertionError>()),
    );
  });
}

class _ImplementsPlatform implements AppLimiterPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
