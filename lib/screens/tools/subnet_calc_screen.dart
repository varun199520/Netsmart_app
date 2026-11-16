import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ipv4.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Subnet Calculator + Subnet Breakout (same outputs as the web page,
/// computed on the phone).
class SubnetCalcScreen extends StatefulWidget {
  const SubnetCalcScreen({super.key});

  @override
  State<SubnetCalcScreen> createState() => _SubnetCalcScreenState();
}

class _SubnetCalcScreenState extends State<SubnetCalcScreen> {
  final _address = TextEditingController();
  final _mask = TextEditingController();
  final _supernet = TextEditingController();
  int? _newPrefix;
  Ipv4Subnet? _subnet;
  String? _error;
  Ipv4Subnet? _super;
  String? _superError;

  static final _n = NumberFormat.decimalPattern();

  @override
  void dispose() {
    _address.dispose();
    _mask.dispose();
    _supernet.dispose();
    super.dispose();
  }

  void _calc() {
    FocusScope.of(context).unfocus();
    setState(() {
      try {
        final s = parseSubnet(_address.text, _mask.text);
        if (s.prefix < 8) throw const FormatException('Use a prefix of /8 or longer.');
        _subnet = s;
        _error = null;
      } on FormatException catch (e) {
        _subnet = null;
        _error = e.message;
      }
    });
  }

  void _parseSupernet(String text) {
    setState(() {
      try {
        final s = parseSubnet(text);
        if (s.prefix < 15) throw const FormatException('Use a supernet of /15 or longer.');
        _super = s;
        _superError = null;
        if (_newPrefix != null && _newPrefix! <= s.prefix) _newPrefix = null;
      } on FormatException catch (e) {
        _super = null;
        _superError = text.trim().isEmpty ? null : e.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _subnet;
    final sup = _super;
    final pieces = sup != null && _newPrefix != null ? sup.split(_newPrefix!, limit: 1024) : const <Ipv4Subnet>[];
    final total = sup != null && _newPrefix != null ? 1 << (_newPrefix! - sup.prefix) : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Subnet Calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          SectionCard(title: 'Subnet', children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _address,
                  autocorrect: false,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: NS.mono.copyWith(fontSize: 15),
                  decoration: const InputDecoration(labelText: 'IP address', hintText: '10.20.30.0/24'),
                  onSubmitted: (_) => _calc(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _mask,
                  autocorrect: false,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: NS.mono.copyWith(fontSize: 15),
                  decoration: const InputDecoration(labelText: 'Mask / prefix', hintText: '24'),
                  onSubmitted: (_) => _calc(),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton(onPressed: _calc, child: const Text('Calculate')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: NS.danger, fontSize: 13)),
            ],
            if (s != null) ...[
              const SizedBox(height: 12),
              KV('Subnet', s.cidr, mono: true),
              KV('Prefix length', '/${s.prefix}', mono: true),
              KV('Subnet mask', formatIpv4(s.mask), mono: true),
              KV('Wildcard', formatIpv4(s.wildcard), mono: true),
              KV('Usable IPs', '${formatIpv4(s.firstUsable)} – ${formatIpv4(s.lastUsable)}', mono: true),
              KV('Network', formatIpv4(s.network), mono: true),
              KV('Broadcast', formatIpv4(s.broadcast), mono: true),
              KV('Usable hosts', _n.format(s.usableHosts)),
            ],
          ]),
          const SizedBox(height: 16),
          SectionCard(title: 'Subnet breakout', children: [
            TextField(
              controller: _supernet,
              autocorrect: false,
              keyboardType: TextInputType.url,
              style: NS.mono.copyWith(fontSize: 15),
              decoration: InputDecoration(labelText: 'Supernet', hintText: '10.20.0.0/22', errorText: _superError),
              onChanged: _parseSupernet,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('${sup?.prefix}'),
              initialValue: _newPrefix,
              dropdownColor: NS.surface,
              decoration: const InputDecoration(labelText: 'Split into'),
              items: [
                if (sup != null)
                  for (var p = sup.prefix + 1; p <= 32 && p <= sup.prefix + 12; p++)
                    DropdownMenuItem(value: p, child: Text('/$p  (${_n.format(1 << (p - sup.prefix))} subnets)')),
              ],
              onChanged: sup == null ? null : (p) => setState(() => _newPrefix = p),
            ),
            if (pieces.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                total > pieces.length
                    ? 'Showing the first ${_n.format(pieces.length)} of ${_n.format(total)} subnets'
                    : '${_n.format(total)} subnets',
                style: const TextStyle(color: NS.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              for (final (i, p) in pieces.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: NS.borderMuted))),
                  child: Row(children: [
                    SizedBox(
                      width: 36,
                      child: Text('${i + 1}', style: const TextStyle(color: NS.textDim, fontSize: 12)),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.cidr, style: NS.mono.copyWith(fontSize: 14, color: NS.text)),
                        Text('${formatIpv4(p.firstUsable)} – ${formatIpv4(p.lastUsable)} · bcast ${formatIpv4(p.broadcast)}',
                            style: NS.mono.copyWith(fontSize: 11.5, color: NS.textSecondary)),
                      ]),
                    ),
                    Text(_n.format(p.usableHosts), style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
                  ]),
                ),
            ],
          ]),
        ],
      ),
    );
  }
}
