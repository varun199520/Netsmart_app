import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'job_screen.dart';
import 'switch_screen.dart';

Future<void> showPortSheet(
  BuildContext context, {
  required String switchId,
  required String switchName,
  required String portName,
  Json? port,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PortSheet(switchId: switchId, switchName: switchName, portName: portName, port: port),
  );
}

bool _samePort(String a, String b) => a.toLowerCase() == b.toLowerCase() || shortPort(a).toLowerCase() == shortPort(b).toLowerCase();

class _PortSheet extends StatefulWidget {
  const _PortSheet({required this.switchId, required this.switchName, required this.portName, this.port});

  final String switchId;
  final String switchName;
  final String portName;
  final Json? port;

  @override
  State<_PortSheet> createState() => _PortSheetState();
}

class _PortSheetState extends State<_PortSheet> {
  Json? _actions;
  Json? _port;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _port = widget.port;
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    try {
      final detail = await api.switchDetail(widget.switchId);
      Json? port = _port;
      if (port == null) {
        final ports = jsonList((await api.switchPorts(widget.switchId))['ports']);
        port = ports.where((p) => _samePort(str(p['name']), widget.portName)).firstOrNull;
      }
      if (!mounted) return;
      setState(() {
        _actions = jsonMap(detail['actions']);
        _port = port;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String get _portName => str(_port?['name'], widget.portName);

  Future<void> _submit(String kind) async {
    final nav = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      final job = await context.read<AppState>().api.submitJob({
        'kind': kind,
        'switch_id': widget.switchId,
        'port': _portName,
      });
      nav.pop();
      nav.push(MaterialPageRoute<void>(builder: (_) => JobScreen(initial: job)));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showSnack(context, e.message, error: true);
      }
    }
  }

  Future<void> _bounce() async {
    final ok = await confirm(context,
        title: 'Bounce $_portName?',
        body: 'The port on ${widget.switchName} will be shut and re-enabled. '
            'Whatever is plugged in loses its connection for a few seconds.',
        action: 'Bounce',
        destructive: true);
    if (ok) await _submit('bounce');
  }

  Future<void> _iseRemoval() async {
    final ok = await confirm(context,
        title: 'Remove ISE from $_portName?',
        body: 'Port authentication is removed temporarily so the device can connect without ISE. '
            'NetSmart restores it automatically.',
        action: 'Remove ISE',
        destructive: true);
    if (ok) await _submit('ise_removal');
  }

  void _configure() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => ConfigurePortScreen(
        switchId: widget.switchId,
        switchName: widget.switchName,
        portName: _portName,
        port: _port,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final port = _port;
    final actions = _actions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_portName, style: NS.mono.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(widget.switchName, style: const TextStyle(color: NS.textSecondary, fontSize: 13)),
        if (port != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill(portStatusLabel(str(port['status'])), color: portStatusColor(str(port['status']))),
            if (port['disabled'] == true) const Pill('shut', color: NS.danger),
            if (port['access_vlan'] != null) Pill('vlan ${port['access_vlan']}', color: NS.accent),
            if (port['voice_vlan'] != null) Pill('voice ${port['voice_vlan']}', color: NS.cyan),
          ]),
          if (str(port['description']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(str(port['description']), style: const TextStyle(fontSize: 13.5)),
          ],
        ],
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: NS.danger))
        else if (actions == null)
          const Padding(padding: EdgeInsets.all(16), child: Loading())
        else if (!actions.values.any((v) => v == true))
          const Text("You don't have permission to change ports on this switch.",
              style: TextStyle(color: NS.textSecondary))
        else
          AbsorbPointer(
            absorbing: _submitting,
            child: Opacity(
              opacity: _submitting ? 0.5 : 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (actions['read'] == true)
                  _ActionTile(
                    icon: Icons.description_outlined,
                    title: 'Read live config',
                    subtitle: 'Show the running config of this port',
                    onTap: () => _submit('port_read'),
                  ),
                if (actions['bounce'] == true)
                  _ActionTile(
                    icon: Icons.restart_alt,
                    title: 'Bounce port',
                    subtitle: 'Shut and re-enable',
                    color: NS.warning,
                    onTap: _bounce,
                  ),
                if (actions['configure'] == true)
                  _ActionTile(
                    icon: Icons.tune,
                    title: 'Configure',
                    subtitle: 'VLAN, voice VLAN, description, enable/disable',
                    onTap: _configure,
                  ),
                if (actions['ise_removal'] == true)
                  _ActionTile(
                    icon: Icons.shield_outlined,
                    title: 'Remove ISE temporarily',
                    subtitle: 'Let a device connect without port authentication',
                    color: NS.orange,
                    onTap: _iseRemoval,
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: NS.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: NS.border)),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(icon, color: color ?? NS.accent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onTap,
        ),
      ),
    );
  }
}

class ConfigurePortScreen extends StatefulWidget {
  const ConfigurePortScreen({
    super.key,
    required this.switchId,
    required this.switchName,
    required this.portName,
    this.port,
  });

  final String switchId;
  final String switchName;
  final String portName;
  final Json? port;

  @override
  State<ConfigurePortScreen> createState() => _ConfigurePortScreenState();
}

class _ConfigurePortScreenState extends State<ConfigurePortScreen> {
  List<Json>? _vlans;
  String? _error;
  String? _vlan;
  bool _voice = false;
  bool _enabled = true;
  bool _submitting = false;
  late final String _originalDescription;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final port = widget.port ?? const {};
    _originalDescription = str(port['description']);
    _description = TextEditingController(text: _originalDescription);
    _voice = port['voice_vlan'] != null;
    _enabled = port['disabled'] != true;
    _vlan = port['access_vlan'] == null ? null : str(port['access_vlan']);
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vlans = await context.read<AppState>().api.switchVlans(widget.switchId);
      if (!mounted) return;
      setState(() {
        _vlans = vlans;
        final usable = vlans.where((v) => v['suspended'] != true).map((v) => str(v['vlan'])).toSet();
        if (!usable.contains(_vlan)) _vlan = null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final vlan = _vlan;
    if (vlan == null) return;
    final description = _description.text.trim();
    final changes = [
      'access VLAN $vlan',
      _voice ? 'voice VLAN on' : 'no voice VLAN',
      if (description != _originalDescription) 'description "${description.isEmpty ? '(none)' : description}"',
      _enabled ? 'port enabled' : 'port SHUT DOWN',
    ];
    final ok = await confirm(context,
        title: 'Apply to ${widget.portName}?',
        body: '${widget.switchName}\n\n${changes.join('\n')}',
        action: 'Apply',
        destructive: !_enabled);
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    try {
      final job = await context.read<AppState>().api.submitJob({
        'kind': 'port_config',
        'switch_id': widget.switchId,
        'port': widget.portName,
        'vlan': vlan,
        'add_voice': _voice,
        'description': description == _originalDescription ? null : description,
        'enabled': _enabled,
      });
      if (mounted) openJob(context, job, replace: true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vlans = _vlans;
    return Scaffold(
      appBar: AppBar(title: Text('Configure ${shortPort(widget.portName)}')),
      body: _error != null
          ? ErrorView(_error!, onRetry: _load)
          : vlans == null
              ? const Loading()
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text(widget.switchName, style: NS.mono.copyWith(color: NS.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _vlan,
                    isExpanded: true,
                    dropdownColor: NS.hover,
                    decoration: const InputDecoration(labelText: 'Access VLAN'),
                    items: [
                      for (final v in vlans)
                        DropdownMenuItem(
                          value: str(v['vlan']),
                          enabled: v['suspended'] != true,
                          child: Text(
                            '${v['vlan']}  ${str(v['name'])}${v['suspended'] == true ? '  (suspended)' : ''}',
                            style: NS.mono.copyWith(
                                fontSize: 14, color: v['suspended'] == true ? NS.textDim : NS.text),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _vlan = v),
                  ),
                  if (vlans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No VLAN list has been collected for this switch yet.',
                          style: TextStyle(color: NS.warning, fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voice VLAN'),
                    subtitle: const Text('Add the switch\'s voice VLAN (for IP phones)',
                        style: TextStyle(color: NS.textSecondary, fontSize: 12.5)),
                    value: _voice,
                    onChanged: (v) => setState(() => _voice = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Port enabled'),
                    subtitle: Text(_enabled ? 'no shutdown' : 'The port will be shut down',
                        style: TextStyle(color: _enabled ? NS.textSecondary : NS.danger, fontSize: 12.5)),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _description,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      helperText: 'Leave unchanged to keep the current description',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _vlan == null || _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Apply'),
                  ),
                ]),
    );
  }
}
