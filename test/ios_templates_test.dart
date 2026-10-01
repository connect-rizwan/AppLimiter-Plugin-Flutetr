import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The plugin and the iOS extensions read the same App Group data through
/// AppLimiterShared.swift, so every copy must be identical.
void main() {
  const pluginCopy =
      'ios/app_limiter/Sources/app_limiter/AppLimiterShared.swift';
  const copies = [
    'ios/extension_templates/AppLimiterShared.swift',
    'example/ios/AppLimiterShield/AppLimiterShared.swift',
    'example/ios/AppLimiterMonitor/AppLimiterShared.swift',
  ];

  for (final copy in copies) {
    test('$copy matches the plugin copy', () {
      expect(
        File(copy).readAsStringSync(),
        File(pluginCopy).readAsStringSync(),
        reason: 'Run tool/add_ios_extensions.rb or copy $pluginCopy again.',
      );
    });
  }

  test('example extensions use the current templates', () {
    for (final (template, example) in [
      (
        'ios/extension_templates/ShieldConfiguration/ShieldConfigurationExtension.swift',
        'example/ios/AppLimiterShield/ShieldConfigurationExtension.swift',
      ),
      (
        'ios/extension_templates/DeviceActivityMonitor/DeviceActivityMonitorExtension.swift',
        'example/ios/AppLimiterMonitor/DeviceActivityMonitorExtension.swift',
      ),
    ]) {
      expect(
        File(example).readAsStringSync(),
        File(template).readAsStringSync(),
        reason: example,
      );
    }
  });
}
