import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

const jobKindLabels = {
  'port_read': 'Read port config',
  'bounce': 'Bounce port',
  'port_config': 'Configure port',
  'ise_removal': 'Remove ISE',
  'dhcp_reserve': 'DHCP reservation',
};

Color jobStatusColor(String status) => switch (status) {
      'succeeded' => NS.success,
      'failed' => NS.danger,
      'running' => NS.accent,
      _ => NS.warning,
    };

void openJob(BuildContext context, Json job, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => JobScreen(initial: job));
  replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
}

class JobScreen extends StatefulWidget {
  const JobScreen({super.key, required this.initial});

  final Json initial;

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  late Json _job = widget.initial;
  Timer? _timer;
  String? _pollError;

  @override
  void initState() {
    super.initState();
    if (_job['done'] != true) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final job = await context.read<AppState>().api.job(str(_job['id']));
      if (!mounted) return;
      setState(() {
        _job = job;
        _pollError = null;
      });
      if (job['done'] == true) _timer?.cancel();
    } on ApiException catch (e) {
      if (mounted) setState(() => _pollError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = str(_job['status'], 'queued');
    final kind = str(_job['kind']);
    final done = _job['done'] == true;
    final result = _job['result'] == null ? null : jsonMap(_job['result']);
    final message = str(_job['message']);
    return Scaffold(
      appBar: AppBar(title: Text(jobKindLabels[kind] ?? 'Job')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          if (!done)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(status == 'succeeded' ? Icons.check_circle : Icons.cancel, color: jobStatusColor(status)),
            ),
          Expanded(
            child: Text(str(_job['target']), style: NS.mono.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Pill(status, color: jobStatusColor(status)),
        ]),
        const SizedBox(height: 6),
        Text(
          done
              ? 'Finished ${ago(_job['finished_at'])}'
              : status == 'running'
                  ? 'Working on the device… you can leave this screen; the job keeps running.'
                  : 'Queued…',
          style: const TextStyle(color: NS.textSecondary, fontSize: 13),
        ),
        if (_pollError != null) ...[
          const SizedBox(height: 8),
          Text(_pollError!, style: const TextStyle(color: NS.warning, fontSize: 12.5)),
        ],
        if (message.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(children: [
            Text(message, style: TextStyle(color: status == 'failed' ? NS.danger : NS.text, fontSize: 13.5)),
          ]),
        ],
        if (result != null) ...[
          const SizedBox(height: 14),
          ..._result(kind, result),
        ],
        const SizedBox(height: 14),
        SectionCard(title: 'Request', children: [
          for (final e in jsonMap(_job['params']).entries)
            if (e.value != null && '${e.value}'.isNotEmpty) KV(_label(e.key), '${e.value}', mono: true),
          KV('Submitted', stamp(_job['created_at'])),
        ]),
      ]),
    );
  }

  List<Widget> _result(String kind, Json r) {
    switch (kind) {
      case 'port_read':
        final config = str(r['config']);
        return [
          SectionCard(title: 'Live port state', children: [
            KV('Description', str(r['description'])),
            KV('Mode', str(r['mode'])),
            KV('Access VLAN', str(r['access_vlan']), mono: true),
            KV('Voice VLAN', str(r['voice_vlan']), mono: true),
            KV('Link', str(r['oper_status']),
                valueColor: str(r['oper_status']) == 'up' ? NS.success : NS.textSecondary),
            if (r['admin_down'] == true) const KV('Admin', 'shutdown', valueColor: NS.danger),
          ]),
          if (config.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Running config',
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => copyText(context, config),
              ),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(config, style: NS.mono.copyWith(fontSize: 12.5, color: NS.text, height: 1.45)),
                ),
              ],
            ),
          ],
        ];
      case 'dhcp_reserve':
        return [
          SectionCard(title: 'Reservation', children: [
            KV('IP', str(r['ip']), mono: true),
            KV('MAC', str(r['mac']), mono: true),
            KV('Name', str(r['name'])),
            if (r['fqdn'] != null) KV('FQDN', str(r['fqdn']), mono: true),
          ]),
          const SizedBox(height: 12),
          SectionCard(title: 'DHCP servers', children: [
            for (final s in jsonList(r['servers']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(s['ok'] == true ? Icons.check_circle_outline : Icons.error_outline,
                      size: 18, color: s['ok'] == true ? NS.success : NS.danger),
                  const SizedBox(width: 8),
                  Text(str(s['server']), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s['noop'] == true ? 'already present' : str(s['detail']),
                        style: const TextStyle(color: NS.textSecondary, fontSize: 13)),
                  ),
                ]),
              ),
          ]),
        ];
      default:
        return [
          SectionCard(title: 'Result', children: [
            if (str(r['detail']).isNotEmpty) KV('Detail', str(r['detail'])),
            if (r['vlan'] != null) KV('VLAN', str(r['vlan']), mono: true),
            if (r.containsKey('voice')) KV('Voice VLAN', str(r['voice']), mono: true),
            if (r['description'] != null) KV('Description', str(r['description'])),
            KV('Link', str(r['oper_status']),
                valueColor: str(r['oper_status']) == 'up' ? NS.success : NS.textSecondary),
            if (r['saved'] != null) KV('Saved to startup', r['saved'] == true ? 'yes' : 'no'),
            if (r['revert_due_at'] != null) KV('ISE restored', stamp(r['revert_due_at']), valueColor: NS.warning),
          ]),
        ];
    }
  }

  static String _label(String key) => switch (key) {
        'add_voice' => 'Voice VLAN',
        'switch_id' => 'Switch',
        'fqdn' => 'FQDN',
        'ip' => 'IP',
        'mac' => 'MAC',
        'vlan' => 'VLAN',
        _ => key[0].toUpperCase() + key.substring(1).replaceAll('_', ' '),
      };
}
