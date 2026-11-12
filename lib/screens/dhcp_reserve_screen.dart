import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'job_screen.dart';

enum _IpMode { subnet, specific }

class DhcpReserveScreen extends StatefulWidget {
  const DhcpReserveScreen({super.key, this.mac, this.switchId, this.switchName});

  final String? mac;
  final String? switchId;
  final String? switchName;

  @override
  State<DhcpReserveScreen> createState() => _DhcpReserveScreenState();
}

class _DhcpReserveScreenState extends State<DhcpReserveScreen> {
  final _form = GlobalKey<FormState>();
  late final _mac = TextEditingController(text: widget.mac ?? '');
  final _name = TextEditingController();
  final _comment = TextEditingController();
  final _fqdn = TextEditingController();
  final _ip = TextEditingController();
  final _switchQuery = TextEditingController();

  _IpMode _mode = _IpMode.subnet;
  String? _switchId;
  String? _switchName;
  List<Json>? _subnets;
  String? _subnet;
  String? _subnetError;
  List<Json> _switchMatches = [];
  Timer? _debounce;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.switchId != null) _pickSwitch(widget.switchId!, widget.switchName ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_mac, _name, _comment, _fqdn, _ip, _switchQuery]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSwitch(String id, String name) async {
    setState(() {
      _switchId = id;
      _switchName = name;
      _switchMatches = [];
      _subnets = null;
      _subnet = null;
      _subnetError = null;
    });
    try {
      final subnets = await context.read<AppState>().api.dhcpSubnets(id);
      if (!mounted || _switchId != id) return;
      setState(() {
        _subnets = subnets;
        if (subnets.length == 1) _subnet = str(subnets.first['subnet']);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _subnetError = e.message);
    }
  }

  void _searchSwitches(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().length < 2) {
        setState(() => _switchMatches = []);
        return;
      }
      try {
        final rows = await context.read<AppState>().api.switches(q.trim());
        if (mounted && _switchQuery.text == q) setState(() => _switchMatches = rows.take(8).toList());
      } on ApiException catch (e) {
        if (mounted) showSnack(context, e.message, error: true);
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_mode == _IpMode.subnet && _subnet == null) {
      showSnack(context, 'Pick a subnet.', error: true);
      return;
    }
    final target = _mode == _IpMode.specific ? _ip.text.trim() : 'the next free IP in $_subnet';
    final ok = await confirm(context,
        title: 'Create reservation?',
        body: '${_mac.text.trim()} → $target\nName: ${_name.text.trim()}\n\nIt is written to every DHCP server.',
        action: 'Create');
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    try {
      final job = await context.read<AppState>().api.submitJob({
        'kind': 'dhcp_reserve',
        'mac': _mac.text.trim(),
        'name': _name.text.trim(),
        'comment': _comment.text.trim(),
        'fqdn': _fqdn.text.trim(),
        if (_mode == _IpMode.specific) 'ip': _ip.text.trim() else 'subnet': _subnet,
        if (_mode == _IpMode.subnet && _switchId != null) 'switch_id': _switchId,
      });
      if (mounted) openJob(context, job, replace: true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showSnack(context, e.message, error: true);
      }
    }
  }

  static final _macRe = RegExp(r'^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$|^([0-9a-fA-F]{4}\.){2}[0-9a-fA-F]{4}$|^[0-9a-fA-F]{12}$');
  static final _ipRe = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New DHCP reservation')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextFormField(
              controller: _mac,
              autocorrect: false,
              enableSuggestions: false,
              style: NS.mono,
              decoration: const InputDecoration(labelText: 'MAC address', hintText: 'aa:bb:cc:dd:ee:ff'),
              validator: (v) => _macRe.hasMatch((v ?? '').trim()) ? null : 'Enter a valid MAC address',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              autocorrect: false,
              maxLength: 64,
              decoration: const InputDecoration(labelText: 'Device name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _comment,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Comment (optional)'),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _fqdn,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'DNS name (optional)', hintText: 'host.example.org'),
            ),
            const SizedBox(height: 20),
            SegmentedButton<_IpMode>(
              segments: const [
                ButtonSegment(value: _IpMode.subnet, label: Text('Next free IP')),
                ButtonSegment(value: _IpMode.specific, label: Text('Specific IP')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: NS.surface,
                selectedBackgroundColor: NS.accent.withValues(alpha: 0.18),
                selectedForegroundColor: NS.text,
                foregroundColor: NS.textSecondary,
                side: const BorderSide(color: NS.border),
              ),
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == _IpMode.specific)
              TextFormField(
                controller: _ip,
                autocorrect: false,
                style: NS.mono,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'IP address'),
                validator: (v) => _ipRe.hasMatch((v ?? '').trim()) ? null : 'Enter an IPv4 address',
              )
            else
              ..._subnetPicker(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create reservation'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _subnetPicker() {
    final subnets = _subnets;
    if (_switchId == null) {
      return [
        TextField(
          controller: _switchQuery,
          autocorrect: false,
          enableSuggestions: false,
          style: NS.mono,
          decoration: const InputDecoration(
            labelText: 'Switch the device plugs into',
            prefixIcon: Icon(Icons.lan_outlined, size: 20, color: NS.textSecondary),
          ),
          onChanged: _searchSwitches,
        ),
        for (final s in _switchMatches)
          ListTile(
            dense: true,
            title: Text(str(s['name']), style: NS.mono.copyWith(fontSize: 13.5)),
            subtitle: Text(str(s['ip']), style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
            onTap: () {
              FocusScope.of(context).unfocus();
              _pickSwitch(str(s['id']), str(s['name']));
            },
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('The switch decides which subnets you can pick from.',
              style: TextStyle(color: NS.textDim, fontSize: 12)),
        ),
      ];
    }
    return [
      Row(children: [
        const Icon(Icons.lan_outlined, size: 18, color: NS.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(_switchName ?? '', style: NS.mono.copyWith(fontSize: 14))),
        TextButton(
          onPressed: () => setState(() {
            _switchId = null;
            _subnets = null;
            _subnet = null;
            _switchQuery.clear();
          }),
          child: const Text('Change'),
        ),
      ]),
      const SizedBox(height: 8),
      if (_subnetError != null)
        Text(_subnetError!, style: const TextStyle(color: NS.danger))
      else if (subnets == null)
        const Padding(padding: EdgeInsets.all(16), child: Loading())
      else if (subnets.isEmpty)
        const Text('No DHCP subnets were found on this switch. Use a specific IP instead.',
            style: TextStyle(color: NS.warning, fontSize: 13))
      else
        RadioGroup<String>(
          groupValue: _subnet,
          onChanged: (v) => setState(() => _subnet = v),
          child: Column(children: [
            for (final s in subnets)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: str(s['subnet']),
                title: Text(str(s['subnet']), style: NS.mono.copyWith(fontSize: 14)),
                subtitle: Text(
                  ['vlan ${s['vlan']}', if (str(s['description']).isNotEmpty) s['description']].join(' · '),
                  style: const TextStyle(color: NS.textSecondary, fontSize: 12),
                ),
              ),
          ]),
        ),
    ];
  }
}
