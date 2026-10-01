// Adds the app_limiter iOS extensions to your app's Xcode project.
//
// Run from your Flutter app's root directory:
//
//   dart run app_limiter:setup_ios --app-group group.com.your.app
//
// Needs Ruby with the `xcodeproj` gem, which comes with CocoaPods.

import 'dart:io';
import 'dart:isolate';

Future<void> main(List<String> args) async {
  String? option(String name) {
    final index = args.indexOf('--$name');
    return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
  }

  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(
      'Usage: dart run app_limiter:setup_ios --app-group <group.id> '
      '[--project ios/Runner.xcodeproj]',
    );
    return;
  }

  final appGroup = option('app-group');
  final project = option('project') ?? 'ios/Runner.xcodeproj';
  if (appGroup == null || !appGroup.startsWith('group.')) {
    stderr.writeln(
      'Pass the App Group to share with the extensions, e.g. '
      '--app-group group.com.your.app',
    );
    exitCode = 64;
    return;
  }
  if (!Directory(project).existsSync()) {
    stderr.writeln('Xcode project not found: $project');
    exitCode = 66;
    return;
  }

  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:app_limiter/app_limiter.dart'),
  );
  if (library == null) {
    stderr.writeln('Could not locate the app_limiter package.');
    exitCode = 70;
    return;
  }
  final script = File.fromUri(library.resolve('../tool/add_ios_extensions.rb'));

  final result = await Process.start('ruby', [
    script.path,
    project,
    appGroup,
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln(
      'Setup failed. Make sure Ruby and the xcodeproj gem (part of '
      'CocoaPods) are installed.',
    );
  }
}
