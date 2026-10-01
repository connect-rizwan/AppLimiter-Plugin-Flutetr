import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_limiter_example/main.dart';

// 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
  68, 174, 66, 96, 130,
]);

void main() {
  const channel = MethodChannel('app_limiter');
  const events = EventChannel('app_limiter/events');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getPlatformVersion':
          return 'Test 1.0';
        case 'getPermissionStatus':
          return {'overlay': true, 'usageAccess': false, 'notifications': true};
        case 'getAuthorizationStatus':
          return 'notDetermined';
        case 'getBlockingState':
          return {
            'active': true,
            'blockAll': false,
            'blockedPackages': ['com.a'],
          };
        case 'isEnterpriseCapable':
        case 'isEnterpriseModeEnabled':
          return false;
        case 'getInstalledApps':
          return [
            {'packageName': 'com.a', 'name': 'Alpha', 'icon': _png},
            {'packageName': 'com.b', 'name': 'Beta', 'category': 'game'},
          ];
      }
      return null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  testWidgets('shows typed status on Android', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Running on: Test 1.0'), findsOneWidget);
    expect(find.text('Missing permissions: usageAccess'), findsOneWidget);
    expect(find.textContaining('Blocking: active'), findsOneWidget);
    expect(find.text('Choose apps to block'), findsOneWidget);
    expect(find.text('Choose apps'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('shows iOS controls on iOS', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose apps'), findsOneWidget);
    expect(find.text('Choose apps to block'), findsNothing);
    expect(find.text('Missing permissions: screenTime'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('app picker blocks newly checked and unblocks unchecked apps', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chooseAndroidApps')));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('com.b · game'), findsOneWidget);

    // com.a starts checked (already blocked); swap it for com.b.
    await tester.tap(find.text('Alpha'));
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveApps')));
    await tester.pumpAndSettle();

    final blockCall = calls.lastWhere((c) => c.method == 'blockApps');
    final unblockCall = calls.lastWhere((c) => c.method == 'unblockApps');
    expect(blockCall.arguments, {
      'packageNames': ['com.b'],
      'durationMs': null,
    });
    expect(unblockCall.arguments, {
      'packageNames': ['com.a'],
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
