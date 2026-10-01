import 'package:app_limiter/app_limiter.dart';
import 'package:app_limiter/app_limiter_method_channel.dart';
import 'package:app_limiter/app_limiter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records every call so tests can assert the facade forwards correctly.
class FakeAppLimiterPlatform extends AppLimiterPlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = <String>[];
  final List<Object?> arguments = <Object?>[];

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
  Future<void> selectAndConfigureIosAppRestrictions({
    Map<String, dynamic>? schedule,
  }) async => _record('selectAndConfigureIosAppRestrictions', schedule);

  @override
  Future<void> configureIosSchedule(Map<String, dynamic> schedule) async =>
      _record('configureIosSchedule', schedule);

  @override
  Future<bool> showIOSAppPicker() async {
    _record('showIOSAppPicker');
    return true;
  }

  @override
  Future<void> blockIOSApps() async => _record('blockIOSApps');

  @override
  Future<void> unblockIOSApps() async => _record('unblockIOSApps');

  @override
  Future<bool> isIOSAppsBlocked() async {
    _record('isIOSAppsBlocked');
    return true;
  }

  @override
  Future<String> getIOSAuthorizationStatus() async {
    _record('getIOSAuthorizationStatus');
    return 'approved';
  }

  @override
  Future<bool> requestIosPermission() async {
    _record('requestIosPermission');
    return true;
  }

  @override
  Future<bool> isAndroidPermissionAllowed() async {
    _record('isAndroidPermissionAllowed');
    return true;
  }

  @override
  Future<void> requestAndroidPermission() async =>
      _record('requestAndroidPermission');

  @override
  Future<void> blockAndroidApp({required String packageName}) async =>
      _record('blockAndroidApp', packageName);

  @override
  Future<void> unblockAndroidApp({required String packageName}) async =>
      _record('unblockAndroidApp', packageName);

  @override
  Future<void> blockAllAndroidApps() async => _record('blockAllAndroidApps');

  @override
  Future<void> unblockAllAndroidApps() async =>
      _record('unblockAllAndroidApps');

  @override
  Future<List<String>> getBlockedAndroidApps() async {
    _record('getBlockedAndroidApps');
    return <String>['com.example.target'];
  }

  @override
  Future<bool> isAndroidBlockingActive() async {
    _record('isAndroidBlockingActive');
    return true;
  }

  @override
  Future<Map<String, dynamic>> getPlatformCapabilities() async {
    _record('getPlatformCapabilities');
    return <String, dynamic>{'platform': 'android'};
  }

  @override
  Future<void> setAndroidEnterpriseModeEnabled({required bool enabled}) async =>
      _record('setAndroidEnterpriseModeEnabled', enabled);

  @override
  Future<bool> isAndroidEnterpriseModeEnabled() async {
    _record('isAndroidEnterpriseModeEnabled');
    return false;
  }

  @override
  Stream<Map<String, dynamic>> getEventStream() {
    _record('getEventStream');
    return Stream<Map<String, dynamic>>.value(<String, dynamic>{'name': 'x'});
  }
}

/// Uses only the base-class defaults.
class BarePlatform extends AppLimiterPlatform with MockPlatformInterfaceMixin {}

void main() {
  final AppLimiterPlatform initialPlatform = AppLimiterPlatform.instance;

  test('$MethodChannelAppLimiter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppLimiter>());
  });

  group('AppLimiter forwards to the platform', () {
    late FakeAppLimiterPlatform fake;
    final plugin = AppLimiter();

    setUp(() {
      fake = FakeAppLimiterPlatform();
      AppLimiterPlatform.instance = fake;
    });

    test('getPlatformVersion', () async {
      expect(await plugin.getPlatformVersion(), '42');
    });

    test('iOS methods', () async {
      await plugin.selectAndConfigureIosAppRestrictions(
        schedule: {'startHour': 8},
      );
      await plugin.configureIosSchedule({'repeats': true});
      expect(await plugin.showIOSAppPicker(), isTrue);
      await plugin.blockIOSApps();
      await plugin.unblockIOSApps();
      expect(await plugin.isIOSAppsBlocked(), isTrue);
      expect(await plugin.getIOSAuthorizationStatus(), 'approved');
      expect(await plugin.requestIosPermission(), isTrue);

      expect(fake.calls, [
        'selectAndConfigureIosAppRestrictions',
        'configureIosSchedule',
        'showIOSAppPicker',
        'blockIOSApps',
        'unblockIOSApps',
        'isIOSAppsBlocked',
        'getIOSAuthorizationStatus',
        'requestIosPermission',
      ]);
      expect(fake.arguments[0], {'startHour': 8});
      expect(fake.arguments[1], {'repeats': true});
    });

    test('Android methods', () async {
      expect(await plugin.isAndroidPermissionAllowed(), isTrue);
      await plugin.requestAndroidPermission();
      await plugin.blockAndroidApp(packageName: 'a.b');
      await plugin.unblockAndroidApp(packageName: 'a.b');
      await plugin.blockAllAndroidApps();
      await plugin.unblockAllAndroidApps();
      expect(await plugin.getBlockedAndroidApps(), ['com.example.target']);
      expect(await plugin.isAndroidBlockingActive(), isTrue);
      await plugin.setAndroidEnterpriseModeEnabled(enabled: true);
      expect(await plugin.isAndroidEnterpriseModeEnabled(), isFalse);
      expect(await plugin.getPlatformCapabilities(), {'platform': 'android'});

      expect(fake.calls, [
        'isAndroidPermissionAllowed',
        'requestAndroidPermission',
        'blockAndroidApp',
        'unblockAndroidApp',
        'blockAllAndroidApps',
        'unblockAllAndroidApps',
        'getBlockedAndroidApps',
        'isAndroidBlockingActive',
        'setAndroidEnterpriseModeEnabled',
        'isAndroidEnterpriseModeEnabled',
        'getPlatformCapabilities',
      ]);
      expect(fake.arguments[2], 'a.b');
      expect(fake.arguments[8], true);
    });

    test('legacy wrappers keep their original block-all behaviour', () async {
      // ignore: deprecated_member_use_from_same_package
      await plugin.blocAndroidApp();
      // ignore: deprecated_member_use_from_same_package
      await plugin.unblocAndroidApp();
      // ignore: deprecated_member_use_from_same_package
      await plugin.blockAndUnblockIOSApp();

      expect(fake.calls, [
        'blockAllAndroidApps',
        'unblockAllAndroidApps',
        'selectAndConfigureIosAppRestrictions',
      ]);
    });

    test('events', () async {
      expect(await plugin.events.first, {'name': 'x'});
    });
  });

  group('AppLimiterPlatform defaults', () {
    final bare = BarePlatform();

    test('unimplemented methods throw UnimplementedError', () {
      expect(bare.getPlatformVersion, throwsUnimplementedError);
      expect(bare.showIOSAppPicker, throwsUnimplementedError);
      expect(bare.blockIOSApps, throwsUnimplementedError);
      expect(bare.blockAllAndroidApps, throwsUnimplementedError);
      expect(bare.getBlockedAndroidApps, throwsUnimplementedError);
      expect(bare.getEventStream, throwsUnimplementedError);
    });

    test('deprecated defaults route to the new methods', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        bare.blockAndroidApps,
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('blockAllAndroidApps'),
          ),
        ),
      );
      // ignore: deprecated_member_use_from_same_package
      expect(
        bare.unblockAndroidApps,
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('unblockAllAndroidApps'),
          ),
        ),
      );
      // ignore: deprecated_member_use_from_same_package
      expect(
        bare.blockAndUnblockIOSApp,
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('selectAndConfigureIosAppRestrictions'),
          ),
        ),
      );
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
