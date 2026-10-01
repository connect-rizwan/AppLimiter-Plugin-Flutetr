// On-device tests that exercise the real native implementation.
//
// Android: grant the permissions first so the blocking path is covered:
//   adb shell appops set com.example.app_limiter_example SYSTEM_ALERT_WINDOW allow
//   adb shell appops set com.example.app_limiter_example GET_USAGE_STATS allow
// Without them the tests check that blocking is refused with permissionDenied.
//
// Run with: flutter test integration_test --no-uninstall

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app_limiter/app_limiter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final limiter = AppLimiter();

  Matcher throwsAppLimiter(AppLimiterErrorCode code) =>
      throwsA(isA<AppLimiterException>().having((e) => e.code, 'code', code));

  testWidgets('getPlatformVersion', (WidgetTester tester) async {
    final String? version = await limiter.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  testWidgets('getPermissionStatus', (tester) async {
    final status = await limiter.getPermissionStatus();
    if (Platform.isIOS) {
      expect(status.iosAuthorizationStatus, isNotNull);
    } else {
      expect(status.iosAuthorizationStatus, isNull);
    }
  });

  group('Android', () {
    const target = 'com.android.chrome';

    tearDown(() async {
      await limiter.unblockAll();
    });

    testWidgets('empty package name is rejected', (tester) async {
      expect(
        () => limiter.android.blockApp(''),
        throwsAppLimiter(AppLimiterErrorCode.invalidArgument),
      );
    });

    testWidgets('iOS APIs report unsupported', (tester) async {
      expect(
        () => limiter.ios.showAppPicker(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
    });

    testWidgets('getInstalledApps lists launchable apps with icons', (
      tester,
    ) async {
      final apps = await limiter.android.getInstalledApps(includeIcons: true);

      expect(apps, isNotEmpty);
      expect(
        apps.map((a) => a.packageName),
        isNot(contains('com.example.app_limiter_example')),
      );
      final chrome = apps.firstWhere((a) => a.packageName == target);
      expect(chrome.name, isNotEmpty);
      expect(chrome.isSystemApp, isTrue);
      expect(chrome.icon, isNotNull);
      // PNG signature.
      expect(chrome.icon!.sublist(0, 4), [137, 80, 78, 71]);

      final sorted = [...apps.map((a) => a.name.toLowerCase())];
      expect(sorted, [...sorted]..sort());

      final userApps = await limiter.android.getInstalledApps(
        includeSystemApps: false,
      );
      expect(userApps.every((a) => !a.isSystemApp), isTrue);
      expect(userApps.every((a) => a.icon == null), isTrue);
    });

    testWidgets('block and unblock apps', (tester) async {
      final allowed = (await limiter.getPermissionStatus()).isGranted;
      if (!allowed) {
        await expectLater(
          limiter.android.blockApp(target),
          throwsAppLimiter(AppLimiterErrorCode.permissionDenied),
        );
        expect((await limiter.getBlockingState()).isActive, isFalse);
        return;
      }

      final stateEvents = <AppLimiterEvent>[];
      final subscription = limiter.events
          .where((e) => e.type == AppLimiterEventType.blockingStateChanged)
          .listen(stateEvents.add);

      // Starts the foreground service; this crashed on Android 14+ before
      // the service declared a foreground service type.
      await limiter.android.blockApps([target, 'com.google.android.youtube']);
      await tester.pump(const Duration(seconds: 2));
      var state = await limiter.getBlockingState();
      expect(state.isActive, isTrue);
      expect(state.blockedPackages, [target, 'com.google.android.youtube']);

      // Unblocking one package keeps the others blocked.
      await limiter.android.unblockApp(target);
      state = await limiter.getBlockingState();
      expect(state.isActive, isTrue);
      expect(state.blockedPackages, ['com.google.android.youtube']);

      await limiter.android.unblockApp('com.google.android.youtube');
      expect((await limiter.getBlockingState()).isActive, isFalse);

      await tester.pump(const Duration(milliseconds: 500));
      await subscription.cancel();
      expect(stateEvents, isNotEmpty);
      expect(stateEvents.last.payload['active'], isFalse);
    });

    testWidgets('block all with an allowlist', (tester) async {
      if (!(await limiter.getPermissionStatus()).isGranted) return;

      await limiter.android.blockAllApps(except: ['com.google.android.gm']);
      var state = await limiter.getBlockingState();
      expect(state.blockAll, isTrue);
      expect(state.allowedPackages, ['com.google.android.gm']);

      await limiter.unblockAll();
      state = await limiter.getBlockingState();
      expect(state.allowedPackages, isEmpty);
    });

    testWidgets('block screen and notification can be configured', (
      tester,
    ) async {
      await limiter.android.setBlockScreen(
        const BlockScreenConfig(title: 'Focus', buttonLabel: 'Close'),
      );
      await limiter.android.setNotification(title: 'Focus mode', text: 'On');
      // Restore defaults for other tests and manual runs.
      await limiter.android.setBlockScreen(const BlockScreenConfig());
      await limiter.android.setNotification();
    });

    testWidgets('block all and unblock all', (tester) async {
      if (!(await limiter.getPermissionStatus()).isGranted) return;

      await limiter.android.blockAllApps();
      await tester.pump(const Duration(seconds: 1));
      final state = await limiter.getBlockingState();
      expect(state.isActive, isTrue);
      expect(state.blockAll, isTrue);

      await limiter.unblockAll();
      expect(
        await limiter.getBlockingState(),
        const BlockingState(isActive: false),
      );
    });
  }, skip: !Platform.isAndroid);

  group('iOS', () {
    testWidgets('unblockAll clears shields', (tester) async {
      await limiter.unblockAll();
      expect((await limiter.getBlockingState()).isActive, isFalse);
    });

    testWidgets('Android APIs report unsupported', (tester) async {
      expect(
        () => limiter.android.getInstalledApps(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
    });

    testWidgets('blockSelectedApps without access fails', (tester) async {
      if ((await limiter.getPermissionStatus()).isGranted) return;
      await expectLater(
        limiter.ios.blockSelectedApps(),
        throwsAppLimiter(AppLimiterErrorCode.permissionDenied),
      );
    });
  }, skip: !Platform.isIOS);
}
