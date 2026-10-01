import 'package:app_limiter/app_limiter_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('app_limiter');
  const EventChannel eventChannel = EventChannel('app_limiter/events');
  late MethodChannelAppLimiter platform;
  late List<MethodCall> calls;
  late Map<String, Object? Function(MethodCall)> responses;

  TestDefaultBinaryMessenger messenger() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    platform = MethodChannelAppLimiter();
    calls = <MethodCall>[];
    responses = <String, Object? Function(MethodCall)>{};
    messenger().setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      final response = responses[call.method];
      return response?.call(call);
    });
  });

  tearDown(() {
    messenger().setMockMethodCallHandler(channel, null);
    messenger().setMockStreamHandler(eventChannel, null);
  });

  group('general', () {
    test('getPlatformVersion', () async {
      responses['getPlatformVersion'] = (_) => 'Android 16';
      expect(await platform.getPlatformVersion(), 'Android 16');
    });

    test(
      'getPlatformCapabilities converts nested maps to String keys',
      () async {
        responses['getCapabilities'] = (_) => <Object?, Object?>{
          'platform': 'android',
          'enterpriseCapable': true,
          'nested': <Object?, Object?>{'a': 1},
        };

        final capabilities = await platform.getPlatformCapabilities();

        expect(capabilities['platform'], 'android');
        expect(capabilities['enterpriseCapable'], true);
        expect(capabilities['nested'], isA<Map<String, dynamic>>());
      },
    );

    test('getPlatformCapabilities returns empty map on null', () async {
      expect(await platform.getPlatformCapabilities(), isEmpty);
    });

    test('native errors are propagated as PlatformException', () async {
      responses['blockAllApps'] = (_) =>
          throw PlatformException(code: 'PERMISSION_DENIED', message: 'nope');

      await expectLater(
        platform.blockAllAndroidApps(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'PERMISSION_DENIED',
          ),
        ),
      );
    });
  });

  group('android', () {
    test('blockAndroidApp sends trimmed package name', () async {
      await platform.blockAndroidApp(packageName: '  com.example.target ');
      expect(calls.single.method, 'blockApp');
      expect(calls.single.arguments, {'packageName': 'com.example.target'});
    });

    test('unblockAndroidApp sends package name', () async {
      await platform.unblockAndroidApp(packageName: 'com.example.target');
      expect(calls.single.method, 'unblockApp');
      expect(calls.single.arguments, {'packageName': 'com.example.target'});
    });

    test('empty package names are rejected before reaching native', () async {
      expect(
        () => platform.blockAndroidApp(packageName: ''),
        throwsArgumentError,
      );
      expect(
        () => platform.unblockAndroidApp(packageName: '   '),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });

    test('blockAllAndroidApps / unblockAllAndroidApps', () async {
      await platform.blockAllAndroidApps();
      await platform.unblockAllAndroidApps();
      expect(calls.map((c) => c.method), ['blockAllApps', 'unblockAllApps']);
    });

    test(
      'deprecated blockAndroidApps / unblockAndroidApps map to all',
      () async {
        // ignore: deprecated_member_use_from_same_package
        await platform.blockAndroidApps();
        // ignore: deprecated_member_use_from_same_package
        await platform.unblockAndroidApps();
        expect(calls.map((c) => c.method), ['blockAllApps', 'unblockAllApps']);
      },
    );

    test('getBlockedAndroidApps', () async {
      responses['getBlockedApps'] = (_) => <Object?>['a.b', 'c.d'];
      expect(await platform.getBlockedAndroidApps(), ['a.b', 'c.d']);
    });

    test('getBlockedAndroidApps returns empty list on null', () async {
      expect(await platform.getBlockedAndroidApps(), isEmpty);
    });

    test('isAndroidBlockingActive', () async {
      responses['isBlockingActive'] = (_) => true;
      expect(await platform.isAndroidBlockingActive(), isTrue);
    });

    test('isAndroidPermissionAllowed handles bool and legacy string', () async {
      responses['checkPermission'] = (_) => true;
      expect(await platform.isAndroidPermissionAllowed(), isTrue);

      responses['checkPermission'] = (_) => 'Approved';
      expect(await platform.isAndroidPermissionAllowed(), isTrue);

      responses['checkPermission'] = (_) => null;
      expect(await platform.isAndroidPermissionAllowed(), isFalse);
    });

    test('requestAndroidPermission', () async {
      responses['requestAuthorization'] = (_) => 'overlay_permission_requested';
      await platform.requestAndroidPermission();
      expect(calls.single.method, 'requestAuthorization');
    });

    test('setAndroidEnterpriseModeEnabled sends argument', () async {
      await platform.setAndroidEnterpriseModeEnabled(enabled: true);
      expect(calls.single.method, 'setEnterpriseMode');
      expect(calls.single.arguments, {'enabled': true});
    });

    test('isAndroidEnterpriseModeEnabled', () async {
      responses['isEnterpriseModeEnabled'] = (_) => true;
      expect(await platform.isAndroidEnterpriseModeEnabled(), isTrue);
    });
  });

  group('ios', () {
    test('selectAndConfigureIosAppRestrictions sends schedule', () async {
      final schedule = {'startHour': 9, 'endHour': 17, 'repeats': true};
      await platform.selectAndConfigureIosAppRestrictions(schedule: schedule);

      // Must not reuse Android's `blockApp`, which would block every app there.
      expect(calls.single.method, 'selectAndConfigureIosAppRestrictions');
      expect(calls.single.arguments, {'schedule': schedule});
    });

    test('blockAndUnblockIOSApp uses the same picker call', () async {
      await platform.blockAndUnblockIOSApp();
      expect(calls.single.method, 'selectAndConfigureIosAppRestrictions');
      expect(calls.single.arguments, {'schedule': null});
    });

    test('configureIosSchedule', () async {
      await platform.configureIosSchedule({'thresholdMinutes': 30});
      expect(calls.single.method, 'configureIosSchedule');
      expect(calls.single.arguments, {
        'schedule': {'thresholdMinutes': 30},
      });
    });

    test('showIOSAppPicker returns confirmation', () async {
      responses['showAppPicker'] = (_) => true;
      expect(await platform.showIOSAppPicker(), isTrue);

      responses['showAppPicker'] = (_) => false;
      expect(await platform.showIOSAppPicker(), isFalse);
    });

    test('blockIOSApps / unblockIOSApps', () async {
      await platform.blockIOSApps();
      await platform.unblockIOSApps();
      expect(calls.map((c) => c.method), ['blockIOSApps', 'unblockIOSApps']);
    });

    test('blockIOSApps propagates NO_SELECTION', () async {
      responses['blockIOSApps'] = (_) =>
          throw PlatformException(code: 'NO_SELECTION');
      await expectLater(
        platform.blockIOSApps(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('isIOSAppsBlocked', () async {
      responses['isIOSAppsBlocked'] = (_) => true;
      expect(await platform.isIOSAppsBlocked(), isTrue);
    });

    test('getIOSAuthorizationStatus defaults to notDetermined', () async {
      expect(await platform.getIOSAuthorizationStatus(), 'notDetermined');

      responses['getAuthorizationStatus'] = (_) => 'approved';
      expect(await platform.getIOSAuthorizationStatus(), 'approved');
    });

    test('requestIosPermission', () async {
      responses['requestPermission'] = (_) => false;
      expect(await platform.requestIosPermission(), isFalse);
    });
  });

  group('events', () {
    test('maps native events to String-keyed maps', () async {
      messenger().setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
            sink.success(<Object?, Object?>{
              'name': 'android_blocking_state_changed',
              'payload': <Object?, Object?>{'active': true},
              'timestamp': 1,
            });
            sink.success('not a map');
            sink.endOfStream();
          },
        ),
      );

      final events = await platform.getEventStream().toList();

      expect(events, hasLength(2));
      expect(events[0]['name'], 'android_blocking_state_changed');
      expect(events[0]['payload'], {'active': true});
      expect(events[1], {'name': 'unknown', 'payload': 'not a map'});
    });

    test('returns the same broadcast stream for every caller', () {
      final stream = platform.getEventStream();
      expect(identical(stream, platform.getEventStream()), isTrue);
      expect(stream.isBroadcast, isTrue);
    });
  });
}
