import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'job_screen.dart';

const _capabilityLabels = {
  'tracker': 'Device tracker',
  'chat': 'AI assistant',
  'switch_read': 'Read switch ports',
  'bounce': 'Bounce ports',
  'configure': 'Configure ports',
  'ise_removal': 'Remove ISE',
  'dhcp': 'DHCP reservations',
};

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _version = '';
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  Future<void> _togglePush(bool on) async {
    final state = context.read<AppState>();
    setState(() => _pushBusy = true);
    final enabled = await state.setPush(on);
    if (!mounted) return;
    setState(() => _pushBusy = false);
    if (on && !enabled) {
      showSnack(context, 'Notifications are off for NetSmart. Turn them on in iOS Settings → NetSmart → Notifications.',
          error: true);
    }
  }

  Future<void> _signOut() async {
    final state = context.read<AppState>();
    if (!state.isDemo) {
      final ok = await confirm(context,
          title: 'Sign out?', body: 'This device will need to sign in again to use NetSmart.', action: 'Sign out');
      if (!ok) return;
    }
    await state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me ?? const {};
    final caps = state.caps;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: NS.accent.withValues(alpha: 0.18),
              child: Text(
                str(me['name'], str(me['username'], '?')).characters.first.toUpperCase(),
                style: const TextStyle(color: NS.accent, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(me['name'], str(me['username'])),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  [me['username'], me['email']].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                  style: const TextStyle(color: NS.textSecondary, fontSize: 13),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in _capabilityLabels.entries)
              if (caps[e.key] == true) Pill(e.value, color: NS.success, icon: Icons.check),
          ]),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('My recent actions'),
              subtitle: const Text('Port and DHCP jobs from this app',
                  style: TextStyle(color: NS.textSecondary, fontSize: 12.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JobsScreen())),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Job notifications'),
              subtitle: Text(
                state.isDemo ? 'Not available in demo mode' : 'Tell me when a port or DHCP job finishes',
                style: const TextStyle(color: NS.textSecondary, fontSize: 12.5),
              ),
              value: me['push_enabled'] == true,
              onChanged: state.isDemo || _pushBusy ? null : _togglePush,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Signed-in devices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeviceSessionsScreen())),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(title: 'About', children: [
          KV('Version', _version),
          KV('Server', state.isDemo ? 'Demo (offline sample data)' : Uri.parse(AppConfig.baseUrl).host, mono: true),
        ]),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: NS.danger, side: const BorderSide(color: NS.border)),
          icon: Icon(state.isDemo ? Icons.exit_to_app : Icons.logout, size: 18),
          label: Text(state.isDemo ? 'Exit demo' : 'Sign out'),
          onPressed: _signOut,
        ),
      ]),
    );
  }
}

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Json>? _jobs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<AppState>().api.jobs();
      if (!mounted) return;
      setState(() {
        _jobs = rows;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _jobs;
    return Scaffold(
      appBar: AppBar(title: const Text('My recent actions')),
      body: _error != null && jobs == null
          ? ErrorView(_error!, onRetry: _load)
          : jobs == null
              ? const Loading()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: jobs.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          CenterMessage(
                            icon: Icons.history,
                            title: 'Nothing yet',
                            body: 'Port bounces, configuration changes and DHCP reservations you make show up here.',
                          ),
                        ])
                      : ListView.separated(
                          itemCount: jobs.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
                          itemBuilder: (context, i) {
                            final j = jobs[i];
                            final status = str(j['status']);
                            return ListTile(
                              title: Text(jobKindLabels[j['kind']] ?? str(j['kind'])),
                              subtitle: Text('${str(j['target'])} · ${ago(j['created_at'])}',
                                  style: NS.mono.copyWith(color: NS.textSecondary, fontSize: 12)),
                              trailing: Pill(status, color: jobStatusColor(status)),
                              onTap: () async {
                                await Navigator.of(context)
                                    .push(MaterialPageRoute<void>(builder: (_) => JobScreen(initial: j)));
                                _load();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  List<Json>? _sessions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<AppState>().api.deviceSessions();
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _revoke(Json s) async {
    final ok = await confirm(context,
        title: 'Sign out ${str(s['device_name'], 'this device')}?',
        body: 'That device will have to sign in again.',
        action: 'Sign out device',
        destructive: true);
    if (!ok || !mounted) return;
    try {
      await context.read<AppState>().api.revokeDeviceSession(str(s['id']));
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('Signed-in devices')),
      body: _error != null && sessions == null
          ? ErrorView(_error!, onRetry: _load)
          : sessions == null
              ? const Loading()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final s = sessions[i];
                      final current = s['current'] == true;
                      return ListTile(
                        leading: Icon(s['platform'] == 'android' ? Icons.android : Icons.phone_iphone),
                        title: Text(str(s['device_name'], 'Unknown device')),
                        subtitle: Text(
                          '${current ? 'This device · ' : ''}app ${str(s['app_version'], '?')} · active ${ago(s['last_used_at'])}',
                          style: const TextStyle(color: NS.textSecondary, fontSize: 12.5),
                        ),
                        trailing: current
                            ? const Pill('current', color: NS.success)
                            : IconButton(
                                tooltip: 'Sign out this device',
                                icon: const Icon(Icons.logout, color: NS.danger, size: 20),
                                onPressed: () => _revoke(s),
                              ),
                      );
                    },
                  ),
                ),
    );
  }
}
