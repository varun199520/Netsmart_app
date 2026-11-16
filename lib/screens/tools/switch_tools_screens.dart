import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../services/api.dart';
import '../../services/ipv4.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../job_screen.dart';
import 'tool_kit.dart';

/// Ping from Switch: the switch that last saw the IP in its ARP table pings it
/// (10 echoes in the chosen VRF). Runs as a server job, like port actions.
class PingScreen extends StatefulWidget {
  const PingScreen({super.key});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final _ip = TextEditingController();
  String? _vrf;
  bool _busy = false;

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (parseIpv4(_ip.text) == null) {
      showSnack(context, 'Enter a valid IPv4 address.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final job = await context.read<AppState>().api.submitJob({'kind': 'ping', 'ip': _ip.text.trim(), 'vrf': _vrf});
      if (mounted) openJob(context, job);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Ping from Switch')),
      body: AsyncBody<Json>(
        load: api.pingOptions,
        builder: (context, options, _) {
          final vrfs = (options['vrfs'] as List? ?? const []).map((v) => '$v').toList();
          _vrf ??= vrfs.isEmpty ? null : vrfs.first;
          return ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(children: [
              TextField(
                controller: _ip,
                autocorrect: false,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: NS.mono.copyWith(fontSize: 15),
                decoration: const InputDecoration(labelText: 'IP address to ping', hintText: '10.20.30.40'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _vrf,
                dropdownColor: NS.surface,
                decoration: const InputDecoration(labelText: 'VRF'),
                items: [for (final v in vrfs) DropdownMenuItem(value: v, child: Text(v, style: NS.mono))],
                onChanged: (v) => setState(() => _vrf = v),
              ),
              const SizedBox(height: 12),
              const Text(
                'NetSmart finds the switch that most recently saw this IP in its ARP table and pings it from there.',
                style: TextStyle(color: NS.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || _ip.text.trim().isEmpty || _vrf == null ? null : _submit,
                icon: const Icon(Icons.network_ping, size: 18),
                label: const Text('Ping'),
              ),
            ]),
          ]);
        },
      ),
    );
  }
}

/// Available Switchports: logs in to a switch and lists ports unused for 12+ weeks.
class PortUsageScreen extends StatefulWidget {
  const PortUsageScreen({super.key});

  @override
  State<PortUsageScreen> createState() => _PortUsageScreenState();
}

class _PortUsageScreenState extends State<PortUsageScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Json> _matches = [];
  bool _searching = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    setState(() {});
    if (text.trim().length < 2) {
      setState(() => _matches = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final rows = await context.read<AppState>().api.switches(text.trim());
        if (mounted && _query.text.trim() == text.trim()) {
          setState(() {
            _matches = rows;
            _error = null;
          });
        }
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _run(Json sw) async {
    final ok = await confirm(context,
        title: 'Check ${str(sw['name'])}?',
        body: 'NetSmart logs in to the switch and reads its interfaces. This can take a few minutes on large stacks.',
        action: 'Check ports');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final job = await context.read<AppState>().api.submitJob({'kind': 'port_usage', 'switch_id': str(sw['id'])});
      if (mounted) openJob(context, job);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Switchports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: _query,
            autocorrect: false,
            enableSuggestions: false,
            style: NS.mono.copyWith(fontSize: 15),
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: 'Switch name or IP',
              prefixIcon: const Icon(Icons.search, color: NS.textSecondary),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) Text(_error!, style: const TextStyle(color: NS.danger)),
          if (_matches.isEmpty && _query.text.trim().length < 2)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: CenterMessage(
                icon: Icons.settings_input_component_outlined,
                title: 'Find free ports on a switch',
                body: 'Pick a switch to list Gigabit ports that are down and unused for 12+ weeks.',
              ),
            )
          else if (_matches.isEmpty && !_searching)
            noResults('No switches match.')
          else
            Card(
              child: Column(children: [
                for (final (i, sw) in _matches.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  ListTile(
                    title: Text(str(sw['name']), style: NS.mono.copyWith(fontSize: 14.5)),
                    subtitle: Text([sw['ip'], sw['site']].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                        style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : () => _run(sw),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

/// Job-screen result for `ping`.
List<Widget> pingResult(BuildContext context, Json r) {
  final output = str(r['output']);
  final rate = r['success_rate'];
  return [
    SectionCard(title: 'Ping', children: [
      KV('From switch', str(r['switch']), mono: true),
      KV('Target', str(r['ip']), mono: true),
      KV('VRF', str(r['vrf']), mono: true),
      if (rate != null)
        KV('Success rate', '$rate%',
            valueColor: rate == 100 ? NS.success : (rate == 0 ? NS.danger : NS.warning)),
    ]),
    if (output.isNotEmpty) ...[
      const SizedBox(height: 12),
      SectionCard(
        title: 'Switch output',
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () => copyText(context, output),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(output, style: NS.mono.copyWith(fontSize: 12.5, color: NS.text, height: 1.45)),
          ),
        ],
      ),
    ],
  ];
}

/// Job-screen result for `port_usage`.
List<Widget> portUsageResult(BuildContext context, Json r) {
  final unused = jsonList(r['unused_ports']);
  return [
    SectionCard(title: str(r['switch'], 'Switch'), children: [
      KV('Uptime', str(r['uptime'])),
      KV('Ports', str(r['total'])),
      KV('In use', '${str(r['used'])} (${str(r['used_pct'])}%)'),
      KV('Unused', '${str(r['unused'])} (${str(r['unused_pct'])}%)', valueColor: NS.success),
    ]),
    const SizedBox(height: 12),
    SectionCard(title: 'Unused ports', children: [
      if (unused.isEmpty) const Text('No unused ports.', style: TextStyle(color: NS.textSecondary)),
      for (final p in unused)
        InkWell(
          onLongPress: () => copyText(context, str(p['interface'])),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(p['interface']), style: NS.mono.copyWith(fontSize: 13.5, color: NS.text)),
                  if (str(p['description']).isNotEmpty)
                    Text(str(p['description']), style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
                ]),
              ),
              Text('last used ${str(p['last_input'], '—')}',
                  style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
            ]),
          ),
        ),
    ]),
  ];
}
