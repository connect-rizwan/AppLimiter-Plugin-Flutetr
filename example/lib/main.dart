import 'dart:async';

import 'package:app_limiter/app_limiter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Limiter example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _limiter = AppLimiter();
  StreamSubscription<AppLimiterEvent>? _eventSubscription;

  String _platformVersion = 'Unknown';
  PermissionStatus? _permissions;
  BlockingState? _blocking;
  bool _enterpriseCapable = false;
  bool _enterpriseEnabled = false;
  List<BlockSchedule> _schedules = const [];
  IosExtensionStatus? _iosExtensions;
  List<IosBlockSchedule> _iosSchedules = const [];
  final List<AppLimiterEvent> _events = <AppLimiterEvent>[];
  bool _busy = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _eventSubscription = _limiter.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, event);
        if (_events.length > 25) _events.removeLast();
      });
      unawaited(_refresh());
    }, onError: (Object error) => debugPrint('Event stream error: $error'));
    unawaited(_loadPlatformVersion());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPlatformVersion() async {
    try {
      final version = await _limiter.getPlatformVersion();
      if (mounted) setState(() => _platformVersion = version ?? 'Unknown');
    } on AppLimiterException catch (e) {
      if (mounted) setState(() => _platformVersion = 'Failed: ${e.message}');
    }
  }

  Future<void> _refresh() async {
    if (!AppLimiter.isSupported) return;
    try {
      final permissions = await _limiter.getPermissionStatus();
      final blocking = await _limiter.getBlockingState();
      var enterpriseCapable = false;
      var enterpriseEnabled = false;
      var schedules = const <BlockSchedule>[];
      if (_isAndroid) {
        enterpriseCapable = await _limiter.android.isEnterpriseCapable();
        enterpriseEnabled = await _limiter.android.isEnterpriseModeEnabled();
        schedules = await _limiter.android.getSchedules();
      }
      IosExtensionStatus? iosExtensions;
      var iosSchedules = const <IosBlockSchedule>[];
      if (_isIOS) {
        iosExtensions = await _limiter.ios.getExtensionStatus();
        iosSchedules = await _limiter.ios.getSchedules();
      }
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _blocking = blocking;
        _enterpriseCapable = enterpriseCapable;
        _enterpriseEnabled = enterpriseEnabled;
        _schedules = schedules;
        _iosExtensions = iosExtensions;
        _iosSchedules = iosSchedules;
      });
    } on AppLimiterException catch (e) {
      _showSnackBar('Failed to load status: ${e.message}');
    }
  }

  /// Runs [action], shows its outcome, and refreshes the status.
  Future<void> _run(String label, Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      _showSnackBar(result == null ? '$label: done' : '$label: $result');
    } on AppLimiterException catch (e) {
      _showSnackBar('$label failed: ${e.code.name} – ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Set<String>?> _pickApps(String title, Set<String> initial) {
    return Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder:
            (_) => AppPickerPage(
              limiter: _limiter,
              title: title,
              initial: initial,
            ),
      ),
    );
  }

  Future<void> _chooseAndroidApps() async {
    final current = _blocking?.blockedPackages.toSet() ?? <String>{};
    final selected = await _pickApps('Block apps', current);
    if (selected == null) return;

    final toBlock = selected.difference(current).toList();
    final toUnblock = current.difference(selected).toList();
    await _run('Update blocked apps', () async {
      await _limiter.android.blockApps(toBlock);
      await _limiter.android.unblockApps(toUnblock);
      return '${selected.length} blocked';
    });
  }

  Future<void> _blockForOneMinute() async {
    final selected = await _pickApps('Block for 1 minute', <String>{});
    if (selected == null || selected.isEmpty) return;
    await _run(
      'Block for 1 minute',
      () => _limiter.android.blockApps(
        selected.toList(),
        duration: const Duration(minutes: 1),
      ),
    );
  }

  Future<void> _addSchedule() async {
    final apps = await _pickApps('Apps to schedule', <String>{});
    if (apps == null || apps.isEmpty || !mounted) return;
    final start = await showTimePicker(
      context: context,
      helpText: 'Block from',
      initialTime: const TimeOfDay(hour: 22, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'Block until',
      initialTime: const TimeOfDay(hour: 7, minute: 0),
    );
    if (end == null) return;

    await _run(
      'Schedule',
      () => _limiter.android.setSchedule(
        BlockSchedule(
          id: 'schedule-${DateTime.now().millisecondsSinceEpoch}',
          packages: apps.toList(),
          start: DailyTime(start.hour, start.minute),
          end: DailyTime(end.hour, end.minute),
        ),
      ),
    );
  }

  Future<(TimeOfDay, TimeOfDay)?> _pickWindow() async {
    final start = await showTimePicker(
      context: context,
      helpText: 'Block from',
      initialTime: const TimeOfDay(hour: 22, minute: 0),
    );
    if (start == null || !mounted) return null;
    final end = await showTimePicker(
      context: context,
      helpText: 'Block until',
      initialTime: const TimeOfDay(hour: 7, minute: 0),
    );
    return end == null ? null : (start, end);
  }

  Future<void> _addIosSchedule() async {
    final window = await _pickWindow();
    if (window == null) return;
    final (start, end) = window;
    await _run(
      'Schedule',
      () => _limiter.ios.setSchedule(
        IosBlockSchedule(
          id: 'schedule-${DateTime.now().millisecondsSinceEpoch}',
          start: DailyTime(start.hour, start.minute),
          end: DailyTime(end.hour, end.minute),
        ),
      ),
    );
  }

  Future<void> _setIosShield(bool custom) async {
    await _run(
      custom ? 'Custom shield' : 'Default shield',
      () => _limiter.ios.setShield(
        custom
            ? const IosShieldConfig(
              title: 'Not now',
              subtitle: '{app} is blocked until you finish your focus time.',
              primaryButtonLabel: 'Close',
              backgroundColor: Color(0xFF1A237E),
              titleColor: Colors.white,
              subtitleColor: Color(0xFFC5CAE9),
              primaryButtonBackgroundColor: Colors.white,
              primaryButtonLabelColor: Color(0xFF1A237E),
            )
            : const IosShieldConfig(),
      ),
    );
  }

  Future<void> _blockAllExcept() async {
    final allowed = await _pickApps(
      'Keep usable',
      _blocking?.allowedPackages.toSet() ?? <String>{},
    );
    if (allowed == null) return;
    await _run(
      'Block all',
      () => _limiter.android.blockAllApps(except: allowed.toList()),
    );
  }

  Future<void> _customizeBlockScreen(bool custom) async {
    await _run(
      custom ? 'Custom block screen' : 'Default block screen',
      () => _limiter.android.setBlockScreen(
        custom
            ? const BlockScreenConfig(
              title: 'Not now',
              message: 'You chose to stay focused until 6 pm.',
              footer: 'App Limiter example',
              backgroundColor: Color(0xFF1A237E),
              textColor: Colors.white,
              buttonLabel: 'Open App Limiter',
              buttonAction: BlockScreenButtonAction.openHostApp,
            )
            : const BlockScreenConfig(),
      ),
    );
  }

  Widget _statusCard() {
    final permissions = _permissions;
    final blocking = _blocking;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text('Running on: $_platformVersion'),
            if (!AppLimiter.isSupported)
              const Text('This platform is not supported.'),
            if (permissions != null)
              Text(
                permissions.isGranted
                    ? 'Permissions: granted'
                    : 'Missing permissions: '
                        '${permissions.missing.map((p) => p.name).join(', ')}',
                key: const Key('permissionText'),
              ),
            if (blocking != null)
              Text(
                'Blocking: ${blocking.isActive ? 'active' : 'off'}'
                '${blocking.blockAll ? ' (all apps)' : ''}'
                '${blocking.blockedPackages.isEmpty ? '' : ' – ${blocking.blockedPackages.length} apps'}'
                '${blocking.allowedPackages.isEmpty ? '' : ' – ${blocking.allowedPackages.length} allowed'}'
                '${blocking.iosBlockedUntil == null ? '' : ' until ${TimeOfDay.fromDateTime(blocking.iosBlockedUntil!).format(context)}'}'
                '${_isIOS ? ' – selection: ${blocking.iosSelectedApplicationCount} apps, '
                        '${blocking.iosSelectedCategoryCount} categories' : ''}',
                key: const Key('blockingText'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _commonSection() {
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed:
                () => _run('Permission', () async {
                  final status = await _limiter.requestPermission();
                  return status.isGranted ? 'granted' : 'still missing';
                }),
            child: const Text('Request permission'),
          ),
          OutlinedButton(
            onPressed: () => _run('Unblock all', _limiter.unblockAll),
            child: const Text('Unblock all'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _androidSection() {
    return [
      const _SectionTitle('Android'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            key: const Key('chooseAndroidApps'),
            onPressed: _chooseAndroidApps,
            child: const Text('Choose apps to block'),
          ),
          ElevatedButton(
            onPressed: () => _run('Block all', _limiter.android.blockAllApps),
            child: const Text('Block all apps'),
          ),
          ElevatedButton(
            onPressed: _blockAllExcept,
            child: const Text('Block all except…'),
          ),
          ElevatedButton(
            onPressed: _blockForOneMinute,
            child: const Text('Block for 1 minute…'),
          ),
          ElevatedButton(
            key: const Key('addSchedule'),
            onPressed: _addSchedule,
            child: const Text('Add schedule…'),
          ),
          OutlinedButton(
            key: const Key('customBlockScreen'),
            onPressed: () => _customizeBlockScreen(true),
            child: const Text('Custom block screen'),
          ),
          OutlinedButton(
            onPressed: () => _customizeBlockScreen(false),
            child: const Text('Default block screen'),
          ),
        ],
      ),
      for (final schedule in _schedules)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _blocking?.activeScheduleIds.contains(schedule.id) == true
                ? Icons.lock_clock
                : Icons.schedule,
          ),
          title: Text('${schedule.start} – ${schedule.end}'),
          subtitle: Text(
            schedule.allApps
                ? 'All apps except ${schedule.except.length}'
                : schedule.packages.join(', '),
          ),
          trailing: IconButton(
            tooltip: 'Remove schedule',
            icon: const Icon(Icons.delete_outline),
            onPressed:
                () => _run(
                  'Remove schedule',
                  () => _limiter.android.removeSchedule(schedule.id),
                ),
          ),
        ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enterprise mode (device owner only)'),
        value: _enterpriseEnabled,
        onChanged:
            _enterpriseCapable
                ? (value) => _run(
                  'Enterprise mode',
                  () => _limiter.android.setEnterpriseModeEnabled(value),
                )
                : null,
      ),
    ];
  }

  List<Widget> _iosSection() {
    return [
      const _SectionTitle('iOS (Screen Time)'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed:
                () => _run('Picker', () async {
                  final confirmed = await _limiter.ios.showAppPicker();
                  return confirmed ? 'saved' : 'cancelled';
                }),
            child: const Text('Choose apps'),
          ),
          ElevatedButton(
            onPressed: () => _run('Block', _limiter.ios.blockSelectedApps),
            child: const Text('Block selected'),
          ),
          OutlinedButton(
            onPressed:
                () => _run(
                  'Pick & block',
                  () => _limiter.ios.showAppPickerAndBlock(
                    schedule: const IosSchedule(startHour: 9, endHour: 22),
                  ),
                ),
            child: const Text('Pick & block in one step'),
          ),
        ],
      ),
      const _SectionTitle('iOS extensions'),
      Text(
        _iosExtensions == null
            ? 'Not loaded'
            : 'App Group: ${_iosExtensions!.appGroup ?? 'not set'}'
                '${_iosExtensions!.appGroupAccessible ? '' : ' (not accessible)'}\n'
                'Shield extension: ${_iosExtensions!.hasShieldConfigurationExtension ? 'yes' : 'no'}\n'
                'Monitor extension: ${_iosExtensions!.hasDeviceActivityMonitorExtension ? 'yes' : 'no'}',
        key: const Key('iosExtensionsText'),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed:
                () => _run(
                  'Block for 15 minutes',
                  () => _limiter.ios.blockSelectedApps(
                    duration: const Duration(minutes: 15),
                  ),
                ),
            child: const Text('Block for 15 min'),
          ),
          ElevatedButton(
            onPressed: _addIosSchedule,
            child: const Text('Add schedule…'),
          ),
          OutlinedButton(
            onPressed: () => _setIosShield(true),
            child: const Text('Custom shield'),
          ),
          OutlinedButton(
            onPressed: () => _setIosShield(false),
            child: const Text('Default shield'),
          ),
        ],
      ),
      for (final schedule in _iosSchedules)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _blocking?.activeScheduleIds.contains(schedule.id) == true
                ? Icons.lock_clock
                : Icons.schedule,
          ),
          title: Text('${schedule.start} – ${schedule.end}'),
          trailing: IconButton(
            tooltip: 'Remove schedule',
            icon: const Icon(Icons.delete_outline),
            onPressed:
                () => _run(
                  'Remove schedule',
                  () => _limiter.ios.removeSchedule(schedule.id),
                ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Limiter example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(),
          const SizedBox(height: 16),
          if (AppLimiter.isSupported) ..._commonSection(),
          if (_isAndroid) ..._androidSection(),
          if (_isIOS) ..._iosSection(),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
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
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(event.type.name),
                subtitle: Text('${event.name} ${event.payload}'),
              ),
        ],
      ),
    );
  }
}

/// Lists installed apps with icons and returns the checked package names.
class AppPickerPage extends StatefulWidget {
  const AppPickerPage({
    super.key,
    required this.limiter,
    required this.initial,
    this.title = 'Block apps',
  });

  final AppLimiter limiter;
  final String title;
  final Set<String> initial;

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  late final Future<List<InstalledApp>> _apps = widget.limiter.android
      .getInstalledApps(includeIcons: true);
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} (${_selected.length})'),
        actions: [
          TextButton(
            key: const Key('saveApps'),
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Save'),
          ),
        ],
      ),
      body: FutureBuilder<List<InstalledApp>>(
        future: _apps,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed: ${snapshot.error}'));
          }
          final apps = snapshot.data;
          if (apps == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _query.toLowerCase();
          final visible =
              apps
                  .where(
                    (app) =>
                        app.name.toLowerCase().contains(query) ||
                        app.packageName.contains(query),
                  )
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search apps',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final app = visible[index];
                    return CheckboxListTile(
                      key: ValueKey(app.packageName),
                      value: _selected.contains(app.packageName),
                      onChanged:
                          (checked) => setState(() {
                            checked == true
                                ? _selected.add(app.packageName)
                                : _selected.remove(app.packageName);
                          }),
                      secondary:
                          app.icon == null
                              ? const Icon(Icons.apps)
                              : Image.memory(app.icon!, width: 40, height: 40),
                      title: Text(app.name),
                      subtitle: Text(
                        '${app.packageName}'
                        '${app.category == AppCategory.undefined ? '' : ' · ${app.category.name}'}',
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
