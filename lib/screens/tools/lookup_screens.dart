import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'tool_kit.dart';

List<String> _strings(dynamic v) => (v as List? ?? const []).map((e) => '$e').toList();

/// DNS Lookup: forward (A) and reverse (PTR) records across every DNS server.
class DnsLookupScreen extends StatelessWidget {
  const DnsLookupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return ToolSearchScreen(
      title: 'DNS Lookup',
      modes: const [SearchMode('q', 'Name or IP', 'hostname, FQDN or IP address', keyboard: TextInputType.url)],
      search: (_, q) => api.dnsLookup(q),
      emptyIcon: Icons.travel_explore,
      emptyTitle: 'Look up a DNS record',
      emptyBody: 'Forward and reverse records from every DNS server, with any that are out of sync.',
      results: (context, r) {
        final records = jsonList(r['records']);
        return [
          ...serverErrors(r['errors']),
          if (records.isEmpty) noResults('No DNS records found for ${r['query']}.'),
          for (final rec in records) ...[
            SectionCard(
              title: str(rec['rtype']),
              trailing: _strings(rec['missing']).isEmpty
                  ? const Pill('in sync', color: NS.success)
                  : Pill('missing on ${_strings(rec['missing']).length}', color: NS.warning),
              children: [
                KV('Name', str(rec['name']), mono: true),
                KV('Points to', str(rec['target']), mono: true),
                KV('On servers', _strings(rec['servers']).join(', ')),
                if (_strings(rec['missing']).isNotEmpty)
                  KV('Missing on', _strings(rec['missing']).join(', '), valueColor: NS.warning),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ];
      },
    );
  }
}

/// DHCP IP/MAC Lookup: lease / reservation state from the primary DHCP server.
class IpMacLookupScreen extends StatelessWidget {
  const IpMacLookupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return ToolSearchScreen(
      title: 'DHCP IP/MAC Lookup',
      modes: const [SearchMode('q', 'IP or MAC', 'IP or MAC address')],
      search: (_, q) => api.ipInfo(q),
      emptyIcon: Icons.lan_outlined,
      emptyTitle: 'Look up an address',
      emptyBody: 'Lease state, DHCP range and reservation for an IP — or every IP a MAC holds.',
      results: (context, r) {
        final rows = jsonList(r['results']);
        return [
          ...serverErrors(r['errors']),
          if (rows.isEmpty) noResults('Nothing found for ${r['query']}.'),
          for (final row in rows) ...[
            _IpInfoCard(row: row),
            const SizedBox(height: 12),
          ],
        ];
      },
    );
  }
}

class _IpInfoCard extends StatelessWidget {
  const _IpInfoCard({required this.row});

  final Json row;

  @override
  Widget build(BuildContext context) {
    final lease = str(row['lease_state']).toUpperCase();
    final conflict = row['is_conflict'] == true;
    return SectionCard(
      title: str(row['ip_address'], 'Address'),
      trailing: conflict
          ? const Pill('conflict', color: NS.danger)
          : row['reserved'] == true
              ? const Pill('reserved', color: NS.purple)
              : Pill(lease.isEmpty ? 'unknown' : lease.toLowerCase(),
                  color: lease == 'LEASED' ? NS.accent : (lease == 'FREE' ? NS.success : NS.textSecondary)),
      children: [
        KV('MAC', str(row['mac_address']), mono: true),
        KV('Hostname', str(row['hostname'])),
        KV('Network', str(row['network']), mono: true),
        KV('DHCP', str(row['dhcp_range'])),
        if (str(row['fixed_address']).isNotEmpty) KV('Reservation', str(row['fixed_address'])),
        if (row['lease_expires'] != null) KV('Lease expires', stamp(row['lease_expires'])),
      ],
    );
  }
}

/// DC Fabric VLAN Tracker: data-center VLANs by subnet/IP, VLAN ID or switch.
class DcVlanScreen extends StatelessWidget {
  const DcVlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return ToolSearchScreen(
      title: 'DC Fabric VLANs',
      modes: const [
        SearchMode('ip', 'Subnet / IP', '10.20.30.0/24 or an IP', keyboard: TextInputType.url),
        SearchMode('vlan', 'VLAN', 'VLAN ID', keyboard: TextInputType.number),
        SearchMode('switch', 'Switch', 'switch name'),
      ],
      search: (mode, q) => api.dcVlans({mode: q}),
      emptyIcon: Icons.storage,
      emptyTitle: 'Find a data-center VLAN',
      emptyBody: 'Search by subnet or IP, VLAN ID, or fabric switch.',
      results: (context, r) {
        final rows = jsonList(r['results']);
        return [
          if (rows.isEmpty) noResults('No data-center VLANs match.'),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${rows.length} result${rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
            ),
          for (final v in rows) ...[
            SectionCard(
              title: 'VLAN ${str(v['vlan'])} · ${str(v['name'])}',
              trailing: Pill(str(v['dc'], 'DC'), color: NS.cyan),
              children: [
                KV('Subnet', str(v['subnet']), mono: true),
                KV('VRF', str(v['vrf']), mono: true),
                KV('Switch', str(v['switch']), mono: true),
                if (str(v['switch_ip']).isNotEmpty) KV('Switch IP', str(v['switch_ip']), mono: true),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ];
      },
    );
  }
}

/// Subnet Lookup: every address in a subnet (gateway / reserved / DNS-only /
/// seen on the network / free), across all DHCP servers.
class SubnetLookupScreen extends StatefulWidget {
  const SubnetLookupScreen({super.key});

  @override
  State<SubnetLookupScreen> createState() => _SubnetLookupScreenState();
}

class _SubnetLookupScreenState extends State<SubnetLookupScreen> {
  String _show = 'all';

  static const _states = {
    'all': 'All',
    'free': 'Free',
    'reserved': 'Reserved',
    'seen': 'Seen',
    'dns': 'DNS only',
  };

  static Color _color(String state) => switch (state) {
        'free' => NS.success,
        'reserved' => NS.purple,
        'seen' => NS.accent,
        'dns' => NS.warning,
        'system' => NS.cyan,
        _ => NS.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return ToolSearchScreen(
      title: 'Subnet Lookup',
      modes: const [SearchMode('net', 'Subnet', '10.20.30.0/24 (up to /22)', keyboard: TextInputType.url)],
      search: (_, q) => api.subnetInventory(q),
      emptyIcon: Icons.grid_view,
      emptyTitle: 'Inspect a subnet',
      emptyBody: 'See which addresses are free, reserved, in DNS only, or seen on the network.',
      results: (context, r) {
        final counts = jsonMap(r['counts']);
        final rows = jsonList(r['results']).where((x) => _show == 'all' || x['state'] == _show).toList();
        return [
          ...serverErrors(r['server_errors']),
          Text('${str(r['network'])} · ${str(r['total'])} addresses',
              style: NS.mono.copyWith(color: NS.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in _states.entries)
              ChoiceChip(
                label: Text(e.key == 'all' ? e.value : '${e.value} ${str(counts[e.key], '0')}'),
                selected: _show == e.key,
                showCheckmark: false,
                onSelected: (_) => setState(() => _show = e.key),
              ),
          ]),
          const SizedBox(height: 10),
          if (rows.isEmpty) noResults('No addresses in this view.'),
          Card(
            child: Column(children: [
              for (final (i, x) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 14),
                _AddressRow(row: x, color: _color(str(x['state']))),
              ],
            ]),
          ),
        ];
      },
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.row, required this.color});

  final Json row;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final name = str(row['name']).isNotEmpty ? str(row['name']) : _strings(row['dns']).join(', ');
    final missing = _strings(row['missing_on']);
    return InkWell(
      onLongPress: () => copyText(context, str(row['ip'])),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          SizedBox(width: 118, child: Text(str(row['ip']), style: NS.mono.copyWith(fontSize: 13.5, color: NS.text))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (name.isNotEmpty)
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              if (str(row['mac']).isNotEmpty)
                Text(str(row['mac']), style: NS.mono.copyWith(fontSize: 11.5, color: NS.textSecondary)),
              if (missing.isNotEmpty)
                Text('missing on ${missing.join(', ')}', style: const TextStyle(color: NS.warning, fontSize: 11.5)),
            ]),
          ),
          Pill(str(row['state_label'], str(row['state'])), color: color),
        ]),
      ),
    );
  }
}
