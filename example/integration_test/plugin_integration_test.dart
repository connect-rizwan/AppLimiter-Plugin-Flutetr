// On-device tests that exercise the real native implementation.
//
// Android: grant the permissions first so the blocking path is covered:
//   adb shell appops set com.example.app_limiter_example SYSTEM_ALERT_WINDOW allow
//   adb shell appops set com.example.app_limiter_example GET_USAGE_STATS allow
// Without them the tests check that blocking is refused with PERMISSION_DENIED.
//
// Run with: flutter test integration_test

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:app_limiter/app_limiter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = AppLimiter();

  testWidgets('getPlatformVersion', (WidgetTester tester) async {
    final String? version = await plugin.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  testWidgets('getPlatformCapabilities reports the platform', (tester) async {
    final capabilities = await plugin.getPlatformCapabilities();
    expect(capabilities['platform'], Platform.isAndroid ? 'android' : 'ios');
  });

  group('Android', () {
    const target = 'com.android.chrome';

    tearDown(() async {
      await plugin.unblockAllAndroidApps();
    });

    testWidgets('empty package name is rejected', (tester) async {
      expect(
        () => plugin.blockAndroidApp(packageName: ''),
        throwsArgumentError,
      );
    });

    testWidgets('block and unblock a package', (tester) async {
      final allowed = await plugin.isAndroidPermissionAllowed();
      if (!allowed) {
        await expectLater(
          plugin.blockAndroidApp(packageName: target),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'PERMISSION_DENIED',
            ),
          ),
        );
        expect(await plugin.isAndroidBlockingActive(), isFalse);
        return;
      }

      final stateEvents = <Map<String, dynamic>>[];
      final subscription = plugin.events
          .where((e) => e['name'] == 'android_blocking_state_changed')
          .listen(stateEvents.add);

      // Starts the foreground service; this crashed on Android 14+ before
      // the service declared a foreground service type.
      await plugin.blockAndroidApp(packageName: target);
      await tester.pump(const Duration(seconds: 2));
      expect(await plugin.isAndroidBlockingActive(), isTrue);
      expect(await plugin.getBlockedAndroidApps(), contains(target));

      // Calling again must not start a second blocking loop or crash.
      await plugin.blockAndroidApp(packageName: target);
      await plugin.blockAndroidApp(packageName: 'com.android.settings');
      expect(
        await plugin.getBlockedAndroidApps(),
        [target, 'com.android.settings']..sort(),
      );

      // Unblocking one package keeps the others blocked.
      await plugin.unblockAndroidApp(packageName: target);
      expect(await plugin.isAndroidBlockingActive(), isTrue);
      expect(await plugin.getBlockedAndroidApps(), ['com.android.settings']);

      await plugin.unblockAndroidApp(packageName: 'com.android.settings');
      expect(await plugin.isAndroidBlockingActive(), isFalse);

      await tester.pump(const Duration(milliseconds: 500));
      await subscription.cancel();
      expect(stateEvents, isNotEmpty);
      expect(stateEvents.last['payload']['active'], isFalse);
    });

    testWidgets('block all and unblock all', (tester) async {
      if (!await plugin.isAndroidPermissionAllowed()) return;

      await plugin.blockAllAndroidApps();
      await tester.pump(const Duration(seconds: 1));
      expect(await plugin.isAndroidBlockingActive(), isTrue);
      final capabilities = await plugin.getPlatformCapabilities();
      expect(capabilities['blockAll'], isTrue);

      await plugin.unblockAllAndroidApps();
      expect(await plugin.isAndroidBlockingActive(), isFalse);
      expect(await plugin.getBlockedAndroidApps(), isEmpty);
    });
  }, skip: !Platform.isAndroid);

  group('iOS', () {
    testWidgets('authorization status is reported', (tester) async {
      final status = await plugin.getIOSAuthorizationStatus();
      expect(['notDetermined', 'denied', 'approved'], contains(status));
    });

    testWidgets('unblock clears shields', (tester) async {
      await plugin.unblockIOSApps();
      expect(await plugin.isIOSAppsBlocked(), isFalse);
    });

    testWidgets('blockIOSApps without access or selection fails', (
      tester,
    ) async {
      final status = await plugin.getIOSAuthorizationStatus();
      if (status == 'approved') return;
      await expectLater(
        plugin.blockIOSApps(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'PERMISSION_DENIED',
          ),
        ),
      );
    });
  }, skip: !Platform.isIOS);
}
