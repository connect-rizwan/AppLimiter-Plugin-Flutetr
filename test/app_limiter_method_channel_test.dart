import 'package:app_limiter/app_limiter.dart';
import 'package:app_limiter/app_limiter_method_channel.dart';
import 'package:flutter/foundation.dart';
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

  Matcher throwsAppLimiter(AppLimiterErrorCode code) =>
      throwsA(isA<AppLimiterException>().having((e) => e.code, 'code', code));

  setUp(() {
    platform = MethodChannelAppLimiter();
    calls = <MethodCall>[];
    responses = <String, Object? Function(MethodCall)>{};
    messenger().setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      final response = responses[call.method];
      if (response == null) throw MissingPluginException();
      return response(call);
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger().setMockMethodCallHandler(channel, null);
    messenger().setMockStreamHandler(eventChannel, null);
  });

  group('errors', () {
    test('PlatformException becomes AppLimiterException with mapped code', () {
      responses['blockAllApps'] = (_) => throw PlatformException(
        code: 'PERMISSION_DENIED',
        message: 'nope',
        details: 'x',
      );

      expect(
        platform.androidBlockAllApps(),
        throwsA(
          isA<AppLimiterException>()
              .having(
                (e) => e.code,
                'code',
                AppLimiterErrorCode.permissionDenied,
              )
              .having((e) => e.message, 'message', 'nope')
              .having((e) => e.details, 'details', 'x'),
        ),
      );
    });

    test('unknown native codes map to unknown', () {
      responses['blockAllApps'] = (_) =>
          throw PlatformException(code: 'SOMETHING_NEW');
      expect(
        platform.androidBlockAllApps(),
        throwsAppLimiter(AppLimiterErrorCode.unknown),
      );
    });

    test('missing native method becomes unsupported', () {
      expect(
        platform.iosShowAppPicker(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
    });

    test('common methods throw unsupported on other platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        platform.getPermissionStatus(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
      expect(
        platform.unblockAll(),
        throwsAppLimiter(AppLimiterErrorCode.unsupported),
      );
      expect(calls, isEmpty);
    });
  });

  group('android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test(
      'getPermissionStatus parses required and optional permissions',
      () async {
        responses['getPermissionStatus'] = (_) => {
          'overlay': true,
          'usageAccess': false,
          'notifications': false,
        };

        final status = await platform.getPermissionStatus();

        expect(status.isGranted, isFalse);
        expect(status.missing, {AppPermission.usageAccess});
        expect(status.optionalMissing, {AppPermission.notifications});
        expect(status.iosAuthorizationStatus, isNull);
      },
    );

    test('requestPermission sends the permission and returns status', () async {
      responses['requestPermission'] = (_) => {
        'overlay': true,
        'usageAccess': true,
        'notifications': true,
      };

      final status = await platform.requestPermission(AppPermission.overlay);

      expect(calls.single.arguments, {'permission': 'overlay'});
      expect(status.isGranted, isTrue);
      expect(status.optionalMissing, isEmpty);
    });

    test(
      'requestPermission without argument asks for the next missing one',
      () async {
        responses['requestPermission'] = (_) => <String, Object>{};
        await platform.requestPermission();
        expect(calls.single.arguments, {'permission': null});
      },
    );

    test('getBlockingState', () async {
      responses['getBlockingState'] = (_) => {
        'active': true,
        'blockAll': false,
        'blockedPackages': ['a.b', 'c.d'],
      };

      expect(
        await platform.getBlockingState(),
        const BlockingState(isActive: true, blockedPackages: ['a.b', 'c.d']),
      );
    });

    test('unblockAll calls unblockAllApps', () async {
      responses['unblockAllApps'] = (_) => null;
      await platform.unblockAll();
      expect(calls.single.method, 'unblockAllApps');
    });

    test('block/unblock apps send package lists', () async {
      responses['blockApps'] = (_) => null;
      responses['unblockApps'] = (_) => null;
      responses['blockAllApps'] = (_) => null;

      await platform.androidBlockApps(['a.b', 'c.d']);
      await platform.androidUnblockApps(['a.b']);
      await platform.androidBlockAllApps();

      expect(calls.map((c) => c.method), [
        'blockApps',
        'unblockApps',
        'blockAllApps',
      ]);
      expect(calls[0].arguments, {
        'packageNames': ['a.b', 'c.d'],
      });
      expect(calls[1].arguments, {
        'packageNames': ['a.b'],
      });
      expect(calls[2].arguments, {'except': <String>[]});
    });

    test('blockAllApps sends the allowlist', () async {
      responses['blockAllApps'] = (_) => null;
      await platform.androidBlockAllApps(except: ['com.whatsapp']);
      expect(calls.single.arguments, {
        'except': ['com.whatsapp'],
      });
    });

    test('getBlockingState parses the allowlist', () async {
      responses['getBlockingState'] = (_) => {
        'active': true,
        'blockAll': true,
        'allowedPackages': ['com.whatsapp'],
      };
      final state = await platform.getBlockingState();
      expect(state.blockAll, isTrue);
      expect(state.allowedPackages, ['com.whatsapp']);
    });

    test('setBlockScreen serializes colors, icon and action', () async {
      responses['setBlockScreen'] = (_) => null;
      final icon = Uint8List.fromList([1, 2]);

      await platform.androidSetBlockScreen(
        BlockScreenConfig(
          title: 'Focus',
          backgroundColor: const Color(0xFF112233),
          textColor: const Color(0x80FFFFFF),
          icon: icon,
          buttonLabel: 'Open',
          buttonAction: BlockScreenButtonAction.openHostApp,
        ),
      );

      final args = calls.single.arguments as Map;
      expect(args['title'], 'Focus');
      expect(args['message'], isNull);
      expect(args['backgroundColor'], 0xFF112233);
      expect(args['textColor'], 0x80FFFFFF);
      expect(args['icon'], icon);
      expect(args['showIcon'], isTrue);
      expect(args['buttonLabel'], 'Open');
      expect(args['buttonAction'], 'openHostApp');
    });

    test('setNotification', () async {
      responses['setNotification'] = (_) => null;
      await platform.androidSetNotification(title: 'T', text: null);
      expect(calls.single.arguments, {'title': 'T', 'text': null});
    });

    test('getInstalledApps parses apps and passes options', () async {
      final icon = Uint8List.fromList([1, 2, 3]);
      responses['getInstalledApps'] = (_) => [
        {
          'packageName': 'com.google.android.youtube',
          'name': 'YouTube',
          'isSystemApp': true,
          'category': 'video',
          'icon': icon,
        },
        {'packageName': 'com.example.game', 'category': 'unexpected'},
      ];

      final apps = await platform.androidGetInstalledApps(
        includeIcons: true,
        includeSystemApps: false,
        iconSize: 48,
      );

      expect(calls.single.arguments, {
        'includeIcons': true,
        'includeSystemApps': false,
        'iconSize': 48,
      });
      expect(apps, hasLength(2));
      expect(apps[0].name, 'YouTube');
      expect(apps[0].isSystemApp, isTrue);
      expect(apps[0].category, AppCategory.video);
      expect(apps[0].icon, icon);
      expect(apps[1].name, 'com.example.game');
      expect(apps[1].category, AppCategory.undefined);
      expect(apps[1].icon, isNull);
    });

    test('enterprise methods', () async {
      responses['isEnterpriseCapable'] = (_) => true;
      responses['setEnterpriseMode'] = (_) => null;
      responses['isEnterpriseModeEnabled'] = (_) => true;

      expect(await platform.androidIsEnterpriseCapable(), isTrue);
      await platform.androidSetEnterpriseModeEnabled(true);
      expect(await platform.androidIsEnterpriseModeEnabled(), isTrue);
      expect(calls[1].arguments, {'enabled': true});
    });
  });

  group('ios', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('getPermissionStatus maps authorization status', () async {
      responses['getAuthorizationStatus'] = (_) => 'denied';
      final denied = await platform.getPermissionStatus();
      expect(denied.missing, {AppPermission.screenTime});
      expect(denied.iosAuthorizationStatus, IosAuthorizationStatus.denied);

      responses['getAuthorizationStatus'] = (_) => 'approved';
      final approved = await platform.getPermissionStatus();
      expect(approved.isGranted, isTrue);
    });

    test('requestPermission prompts then returns status', () async {
      responses['requestPermission'] = (_) => true;
      responses['getAuthorizationStatus'] = (_) => 'approved';

      final status = await platform.requestPermission();

      expect(calls.map((c) => c.method), [
        'requestPermission',
        'getAuthorizationStatus',
      ]);
      expect(status.isGranted, isTrue);
    });

    test(
      'requestPermission for an Android permission does not prompt',
      () async {
        responses['getAuthorizationStatus'] = (_) => 'notDetermined';
        await platform.requestPermission(AppPermission.overlay);
        expect(calls.map((c) => c.method), ['getAuthorizationStatus']);
      },
    );

    test('getBlockingState parses selection counts', () async {
      responses['getBlockingState'] = (_) => {
        'active': true,
        'applicationCount': 2,
        'categoryCount': 1,
        'webDomainCount': 0,
      };

      final state = await platform.getBlockingState();

      expect(state.isActive, isTrue);
      expect(state.iosSelectedApplicationCount, 2);
      expect(state.iosSelectedCategoryCount, 1);
      expect(state.hasIosSelection, isTrue);
    });

    test('unblockAll calls unblockIOSApps', () async {
      responses['unblockIOSApps'] = (_) => null;
      await platform.unblockAll();
      expect(calls.single.method, 'unblockIOSApps');
    });

    test('picker and blocking calls', () async {
      responses['showAppPicker'] = (_) => true;
      responses['blockIOSApps'] = (_) => null;
      responses['selectAndConfigureIosAppRestrictions'] = (_) => null;
      responses['configureIosSchedule'] = (_) => null;

      expect(await platform.iosShowAppPicker(), isTrue);
      await platform.iosBlockSelectedApps();
      await platform.iosShowAppPickerAndBlock(schedule: {'startHour': 9});
      await platform.iosConfigureSchedule({'endHour': 17});

      expect(calls.map((c) => c.method), [
        'showAppPicker',
        'blockIOSApps',
        'selectAndConfigureIosAppRestrictions',
        'configureIosSchedule',
      ]);
      expect(calls[2].arguments, {
        'schedule': {'startHour': 9},
      });
      expect(calls[3].arguments, {
        'schedule': {'endHour': 17},
      });
    });

    test('blockIOSApps propagates noSelection', () {
      responses['blockIOSApps'] = (_) =>
          throw PlatformException(code: 'NO_SELECTION');
      expect(
        platform.iosBlockSelectedApps(),
        throwsAppLimiter(AppLimiterErrorCode.noSelection),
      );
    });
  });

  group('events', () {
    test('native events become typed AppLimiterEvents', () async {
      messenger().setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
            sink.success(<Object?, Object?>{
              'name': 'android_blocking_state_changed',
              'payload': <Object?, Object?>{'active': true},
              'timestamp': 1700000000,
            });
            sink.success(<Object?, Object?>{
              'name': 'android_blocked_app_opened',
              'payload': <Object?, Object?>{'packageName': 'com.game'},
            });
            sink.success(<Object?, Object?>{'name': 'something_new'});
            sink.success('not a map');
            sink.endOfStream();
          },
        ),
      );

      final events = await platform.events.toList();

      expect(events, hasLength(4));
      expect(events[0].type, AppLimiterEventType.blockingStateChanged);
      expect(events[0].payload, {'active': true});
      expect(
        events[0].timestamp,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
      expect(events[1].type, AppLimiterEventType.blockedAppOpened);
      expect(events[1].payload['packageName'], 'com.game');
      expect(events[2].type, AppLimiterEventType.unknown);
      expect(events[2].name, 'something_new');
      expect(events[3].payload, {'value': 'not a map'});
    });

    test('returns the same broadcast stream for every caller', () {
      final stream = platform.events;
      expect(identical(stream, platform.events), isTrue);
      expect(stream.isBroadcast, isTrue);
    });
  });
}
