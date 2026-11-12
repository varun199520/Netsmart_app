import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dhcp_reserve_screen.dart';
import 'port_sheet.dart';
import 'search_screen.dart';

class EndpointScreen extends StatefulWidget {
  const EndpointScreen({super.key, required this.query});

  final String query;

  @override
  State<EndpointScreen> createState() => _EndpointScreenState();
}

class _EndpointScreenState extends State<EndpointScreen> {
  Json? _card;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final state = context.read<AppState>();
    try {
      final card = await state.api.search(widget.query);
      if (!mounted) return;
      setState(() => _card = card);
      if (card['found'] == true) {
        final label = str(jsonMap(card['identity'])['hostname'], str(card['mac'], widget.query));
        await state.prefs.addRecent({'kind': 'endpoint', 'value': widget.query, 'label': label});
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Json get _saved {
    final identity = jsonMap(_card?['identity']);
    return {'kind': 'endpoint', 'value': widget.query, 'label': str(identity['hostname'], widget.query)};
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final card = _card;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.query, style: NS.mono.copyWith(fontSize: 16)),
        actions: [
          if (card?['found'] == true)
            IconButton(
              icon: Icon(state.prefs.isFavorite(_saved) ? Icons.star : Icons.star_border,
                  color: state.prefs.isFavorite(_saved) ? NS.warning : null),
              onPressed: () async {
                await state.prefs.toggleFavorite(_saved);
                setState(() {});
              },
            ),
        ],
      ),
      body: _error != null
          ? ErrorView(_error!, onRetry: _load)
          : card == null
              ? const Loading()
              : RefreshIndicator(onRefresh: _load, child: _body(state, card)),
    );
  }

  Widget _body(AppState state, Json card) {
    final identity = jsonMap(card['identity']);
    final freshness = jsonMap(card['freshness']);
    final wired = card['wired'] == null ? null : jsonMap(card['wired']);
    final gateway = card['gateway'] == null ? null : jsonMap(card['gateway']);
    final wireless = jsonList(card['wireless']);
    final moves = jsonList(card['recent_moves']);
    final warnings = (card['warnings'] as List? ?? []).map((w) => '$w').toList();
    final ips = (card['ips'] as List? ?? []).map((i) => '$i').toList();
    final mac = str(card['mac']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: Text(str(identity['hostname'], mac.isEmpty ? widget.query : mac),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Pill(str(freshness['state'], 'unknown'), color: freshnessColor(str(freshness['state']))),
        ]),
        if (card['message'] != null && card['found'] != true) ...[
          const SizedBox(height: 12),
          SectionCard(children: [Text(str(card['message']), style: const TextStyle(color: NS.textSecondary))]),
        ],
        if (card['found'] == true) ...[
          const SizedBox(height: 4),
          Text('Last seen ${ago(freshness['last_seen'])}', style: const TextStyle(color: NS.textSecondary)),
          const SizedBox(height: 14),
          SectionCard(title: 'Identity', children: [
            KV('MAC', mac, mono: true),
            KV('IP', ips.join(', '), mono: true),
            KV('Category', str(identity['category'])),
            KV('Owner', str(identity['owner'])),
            KV('Vendor', str(identity['vendor'])),
            KV('Connection', str(card['connection'])),
          ]),
          if (wired != null) ...[
            const SizedBox(height: 12),
            _wiredCard(state, wired),
          ],
          if (wireless.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final w in wireless)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(title: 'Wireless', children: [
                  KV('Access point', str(w['ap_name'])),
                  KV('SSID', str(w['ssid'])),
                  KV('Controller', str(w['controller'])),
                  KV('User', str(w['username'])),
                  KV('Location', str(w['location'])),
                  KV('VLAN', str(w['vlan'])),
                  KV('Last seen', ago(w['last_seen'])),
                ]),
              ),
          ],
          if (gateway != null) ...[
            const SizedBox(height: 12),
            SectionCard(title: 'Gateway', children: [
              KV('Device', str(gateway['device']), mono: true),
              KV('Interface', str(gateway['interface']), mono: true),
              KV('Subnet', str(gateway['address']), mono: true),
              if (gateway['vrf'] != null) KV('VRF', str(gateway['vrf'])),
            ]),
          ],
          if (moves.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(title: 'Recent moves', children: [
              for (final m in moves)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${_where(m['from'])}  →  ${_where(m['to'])}   ·  ${ago(m['detected_at'])}',
                      style: const TextStyle(fontSize: 13)),
                ),
            ]),
          ],
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(title: 'Notes', children: [
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 16, color: NS.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
                  ]),
                ),
            ]),
          ],
          if (state.can('dhcp') && mac.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Create DHCP reservation for this MAC'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DhcpReserveScreen(
                  mac: mac,
                  switchId: wired?['switch_id'] == null ? null : str(wired!['switch_id']),
                  switchName: wired == null ? null : str(wired['switch']),
                ),
              )),
            ),
          ],
        ],
      ],
    );
  }

  static String _where(dynamic v) {
    if (v is Map) return [v['switch'], v['port']].where((x) => x != null).join(' ');
    return str(v, '?');
  }

  Widget _wiredCard(AppState state, Json wired) {
    final switchId = wired['switch_id'] == null ? null : str(wired['switch_id']);
    final port = str(wired['port']);
    final linkUp = str(wired['link_state']).toLowerCase() == 'up';
    return SectionCard(
      title: 'Wired location',
      trailing: wired['link_state'] == null
          ? null
          : Pill(linkUp ? 'link up' : 'link ${wired['link_state']}', color: linkUp ? NS.success : NS.danger),
      children: [
        InkWell(
          onTap: switchId == null ? null : () => openSwitch(context, {'id': switchId, 'name': wired['switch']}),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const SizedBox(width: 118, child: Text('Switch', style: TextStyle(color: NS.textSecondary, fontSize: 13))),
              Expanded(
                child: Text(str(wired['switch'], '—'),
                    style: NS.mono.copyWith(fontSize: 13.5, color: switchId == null ? NS.text : NS.accent)),
              ),
              if (switchId != null) const Icon(Icons.chevron_right, size: 18, color: NS.textSecondary),
            ]),
          ),
        ),
        InkWell(
          onTap: switchId == null || port.isEmpty
              ? null
              : () => showPortSheet(context, switchId: switchId, switchName: str(wired['switch']), portName: port),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const SizedBox(width: 118, child: Text('Port', style: TextStyle(color: NS.textSecondary, fontSize: 13))),
              Expanded(
                child: Text(port.isEmpty ? '—' : port,
                    style: NS.mono.copyWith(fontSize: 13.5, color: switchId == null ? NS.text : NS.accent)),
              ),
              if (switchId != null && port.isNotEmpty)
                const Icon(Icons.settings_ethernet, size: 18, color: NS.textSecondary),
            ]),
          ),
        ),
        KV('VLAN', str(wired['vlan']), mono: true),
        KV('Port mode', str(wired['port_mode'])),
        if (wired['voice_vlan'] != null) KV('Voice VLAN', str(wired['voice_vlan']), mono: true),
        KV('Other MACs', str(wired['other_macs_on_port'])),
        if (wired['port_interpretation'] != null) KV('Looks like', str(wired['port_interpretation'])),
        KV('First seen', stamp(wired['first_seen'])),
        KV('Last seen', ago(wired['last_seen'])),
      ],
    );
  }
}
