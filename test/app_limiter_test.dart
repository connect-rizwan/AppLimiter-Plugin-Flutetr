import 'package:app_limiter/app_limiter.dart';
import 'package:app_limiter/app_limiter_method_channel.dart';
import 'package:app_limiter/app_limiter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAppLimiterPlatform
    with MockPlatformInterfaceMixin
    implements AppLimiterPlatform {
  bool blockCalled = false;
  bool unblockCalled = false;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> blockAndUnblockIOSApp() async {
    blockCalled = true;
    unblockCalled = false;
  }

  @override
  Future<bool> requestIosPermission() async {
    return true;
  }

  @override
  Future<bool> isAndroidPermissionAllowed() async {
    return true;
  }

  @override
  Future<void> requestAndroidPermission() async {
    blockCalled = true;
  }

  @override
  Future<void> blockAndroidApps() async {
    blockCalled = true;
  }

  @override
  Future<void> unblockAndroidApps() async {
    blockCalled = true;
  }
  
  @override
  Future<void> blockIOSApps() async {
    blockCalled = true;
  }
  
  @override
  Future<String> getIOSAuthorizationStatus() async {
    return 'authorized';
  }
  
  @override
  Future<bool> isIOSAppsBlocked() async {
    blockCalled = false;
    return true;
  }
  
  @override
  Future<void> showIOSAppPicker() async {
    unblockCalled = false;
  }
  
  @override
  Future<void> unblockIOSApps() async {
    unblockCalled = true;
  }
}

void main() {
  final AppLimiterPlatform initialPlatform = AppLimiterPlatform.instance;

  test('$MethodChannelAppLimiter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppLimiter>());
  });

  test('getPlatformVersion', () async {
    AppLimiter appLimiterPlugin = AppLimiter();
    MockAppLimiterPlatform fakePlatform = MockAppLimiterPlatform();
    AppLimiterPlatform.instance = fakePlatform;

    expect(await appLimiterPlugin.getPlatformVersion(), '42');
  });
}
