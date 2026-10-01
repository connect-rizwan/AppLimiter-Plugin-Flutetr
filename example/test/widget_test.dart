import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_limiter_example/main.dart';

void main() {
  const channel = MethodChannel('app_limiter');
  const events = EventChannel('app_limiter/events');

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getPlatformVersion':
          return 'Test 1.0';
        case 'getCapabilities':
          return {'platform': 'test', 'enterpriseCapable': false};
      }
      return null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  testWidgets('shows platform version and capabilities', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Running on: Test 1.0\n'), findsOneWidget);
    expect(find.textContaining('"platform": "test"'), findsOneWidget);
  });

  testWidgets('shows Android controls on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('androidPackageField')), findsOneWidget);
    expect(find.text('Block all apps'), findsOneWidget);
    expect(find.text('Choose apps'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows iOS controls on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose apps'), findsOneWidget);
    expect(find.byKey(const Key('androidPackageField')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
