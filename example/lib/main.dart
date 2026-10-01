import 'dart:async';
import 'dart:convert';

import 'package:app_limiter/app_limiter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLimiterPlugin = AppLimiter();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _androidPackageController = TextEditingController(
    text: 'com.android.chrome',
  );
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  String _platformVersion = 'Unknown';
  Map<String, dynamic> _capabilities = const <String, dynamic>{};
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  bool _busy = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _listenToEvents();
    unawaited(refreshCapabilities());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _androidPackageController.dispose();
    super.dispose();
  }

  void _listenToEvents() {
    _eventSubscription = _appLimiterPlugin.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, event);
        if (_events.length > 25) {
          _events.removeRange(25, _events.length);
        }
      });
      unawaited(refreshCapabilities());
    }, onError: (Object error) => debugPrint('Event stream error: $error'));
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _appLimiterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;
    setState(() => _platformVersion = platformVersion);
  }

  Future<void> refreshCapabilities() async {
    try {
      final capabilities = await _appLimiterPlugin.getPlatformCapabilities();
      if (!mounted) return;
      setState(() => _capabilities = capabilities);
    } catch (e) {
      _showSnackBar('Failed to load capabilities: $e');
    }
  }

  /// Runs [action], shows its outcome, and refreshes the capability summary.
  Future<void> _run(String label, Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      _showSnackBar(result == null ? '$label: done' : '$label: $result');
    } on PlatformException catch (e) {
      _showSnackBar('$label failed: ${e.code} ${e.message ?? ''}');
    } catch (e) {
      _showSnackBar('$label failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await refreshCapabilities();
    }
  }

  void _showSnackBar(String message) {
    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _packageName => _androidPackageController.text.trim();

  List<Widget> _androidSection() {
    return [
      _SectionTitle('Android'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed:
                () => _run(
                  'Permission',
                  _appLimiterPlugin.isAndroidPermissionAllowed,
                ),
            child: const Text('Check permission'),
          ),
          ElevatedButton(
            onPressed:
                () => _run(
                  'Request permission',
                  _appLimiterPlugin.requestAndroidPermission,
                ),
            child: const Text('Request permission'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('androidPackageField'),
        controller: _androidPackageController,
        decoration: const InputDecoration(
          labelText: 'Android package name',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed:
                () => _run(
                  'Block $_packageName',
                  () => _appLimiterPlugin.blockAndroidApp(
                    packageName: _packageName,
                  ),
                ),
            child: const Text('Block package'),
          ),
          ElevatedButton(
            onPressed:
                () => _run(
                  'Unblock $_packageName',
                  () => _appLimiterPlugin.unblockAndroidApp(
                    packageName: _packageName,
                  ),
                ),
            child: const Text('Unblock package'),
          ),
          ElevatedButton(
            onPressed:
                () => _run('Block all', _appLimiterPlugin.blockAllAndroidApps),
            child: const Text('Block all apps'),
          ),
          ElevatedButton(
            onPressed:
                () => _run(
                  'Unblock all',
                  _appLimiterPlugin.unblockAllAndroidApps,
                ),
            child: const Text('Unblock all'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enterprise mode (device owner only)'),
        value: _capabilities['enterpriseModeEnabled'] == true,
        onChanged:
            _capabilities['enterpriseCapable'] == true
                ? (value) => _run(
                  'Enterprise mode',
                  () => _appLimiterPlugin.setAndroidEnterpriseModeEnabled(
                    enabled: value,
                  ),
                )
                : null,
      ),
    ];
  }

  List<Widget> _iosSection() {
    return [
      _SectionTitle('iOS (Screen Time)'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed:
                () =>
                    _run('Permission', _appLimiterPlugin.requestIosPermission),
            child: const Text('Request permission'),
          ),
          ElevatedButton(
            onPressed: () => _run('Picker', _appLimiterPlugin.showIOSAppPicker),
            child: const Text('Choose apps'),
          ),
          ElevatedButton(
            onPressed: () => _run('Block', _appLimiterPlugin.blockIOSApps),
            child: const Text('Block selected'),
          ),
          ElevatedButton(
            onPressed: () => _run('Unblock', _appLimiterPlugin.unblockIOSApps),
            child: const Text('Unblock'),
          ),
          OutlinedButton(
            onPressed:
                () => _run(
                  'Pick & block',
                  () => _appLimiterPlugin.selectAndConfigureIosAppRestrictions(
                    schedule: {
                      'startHour': 9,
                      'startMinute': 0,
                      'endHour': 22,
                      'endMinute': 0,
                      'repeats': true,
                      'thresholdMinutes': 30,
                    },
                  ),
                ),
            child: const Text('Pick & block in one step'),
          ),
        ],
      ),
    ];
  }

  String _prettyEvent(Map<String, dynamic> event) {
    try {
      return const JsonEncoder.withIndent('  ').convert(event);
    } catch (_) {
      return event.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Running on: $_platformVersion\n'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('Status')),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: refreshCapabilities,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    SelectableText(
                      _capabilities.isEmpty
                          ? 'Not loaded'
                          : _prettyEvent(_capabilities),
                      key: const Key('capabilitiesText'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isAndroid) ..._androidSection(),
            if (_isIOS) ..._iosSection(),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Live plugin events')),
                TextButton(
                  onPressed: () => setState(_events.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_events.isEmpty)
              const Text('No events yet. Trigger actions to see updates.')
            else
              for (final event in _events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    _prettyEvent(event),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
