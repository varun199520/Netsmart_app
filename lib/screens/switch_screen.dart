import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dhcp_reserve_screen.dart';
import 'port_sheet.dart';
import 'search_screen.dart';

class SwitchScreen extends StatefulWidget {
  const SwitchScreen({super.key, required this.switchId, required this.initialName});

  final String switchId;
  final String initialName;

  @override
  State<SwitchScreen> createState() => _SwitchScreenState();
}

class _SwitchScreenState extends State<SwitchScreen> {
  Json? _detail;
  String? _error;
  String? _refreshStatus;
  Timer? _refreshTimer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final detail = await state.api.switchDetail(widget.switchId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
      });
      await state.prefs.addRecent(_saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Json get _saved => {
        'kind': 'switch',
        'id': widget.switchId,
        'value': str(_detail?['name'], widget.initialName),
        'label': str(_detail?['name'], widget.initialName),
      };

  Future<void> _refresh() async {
    final api = context.read<AppState>().api;
    try {
      final res = await api.refreshSwitch(widget.switchId);
      final job = jsonMap(res['job']);
      setState(() => _refreshStatus = str(job['status'], 'pending'));
      _poll(str(job['job_uuid']));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _poll(String jobId) {
    _refreshTimer?.cancel();
    final started = DateTime.now();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (DateTime.now().difference(started).inMinutes >= 5) {
        t.cancel();
        if (mounted) setState(() => _refreshStatus = null);
        return;
      }
      try {
        final job = await context.read<AppState>().api.refreshStatus(widget.switchId, jobId);
        if (!mounted) return;
        final status = str(job['status']);
        if (status == 'success' || status == 'failed') {
          t.cancel();
          setState(() {
            _refreshStatus = null;
            _generation++;
          });
          showSnack(
            context,
            status == 'success'
                ? 'Refreshed from the switch: ${job['locations_updated'] ?? 0} endpoint locations updated.'
                : 'Refresh failed: ${str(job['error'], 'the switch did not answer')}',
            error: status == 'failed',
          );
        } else {
          setState(() => _refreshStatus = status);
        }
      } on ApiException {
        // transient; keep polling until the deadline
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final detail = _detail;
    final name = str(detail?['name'], widget.initialName);
    final actions = jsonMap(detail?['actions']);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name, style: NS.mono.copyWith(fontSize: 16)),
          actions: [
            if (detail != null)
              IconButton(
                icon: Icon(state.prefs.isFavorite(_saved) ? Icons.star : Icons.star_border,
                    color: state.prefs.isFavorite(_saved) ? NS.warning : null),
                onPressed: () async {
                  await state.prefs.toggleFavorite(_saved);
                  setState(() {});
                },
              ),
            if (detail != null)
              PopupMenuButton<String>(
                color: NS.hover,
                onSelected: (v) {
                  if (v == 'refresh') _refresh();
                  if (v == 'dhcp') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DhcpReserveScreen(switchId: widget.switchId, switchName: name),
                    ));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'refresh',
                    enabled: _refreshStatus == null,
                    child: const ListTile(leading: Icon(Icons.sync), title: Text('Refresh from switch')),
                  ),
                  if (detail['dhcp'] == true)
                    const PopupMenuItem(
                      value: 'dhcp',
                      child: ListTile(leading: Icon(Icons.add_link), title: Text('New DHCP reservation')),
                    ),
                ],
              ),
          ],
          bottom: detail == null
              ? null
              : const TabBar(tabs: [Tab(text: 'Endpoints'), Tab(text: 'Ports')]),
        ),
        body: _error != null
            ? ErrorView(_error!, onRetry: _load)
            : detail == null
                ? const Loading()
                : Column(children: [
                    _Header(detail: detail),
                    if (_refreshStatus != null)
                      Container(
                        width: double.infinity,
                        color: NS.accent.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text('Polling the switch ($_refreshStatus)…', style: const TextStyle(fontSize: 13)),
                        ]),
                      ),
                    Expanded(
                      child: TabBarView(children: [
                        _EndpointsTab(key: ValueKey('ep$_generation'), switchId: widget.switchId),
                        _PortsTab(
                          key: ValueKey('pt$_generation'),
                          switchId: widget.switchId,
                          switchName: name,
                          canAct: actions.values.any((v) => v == true),
                        ),
                      ]),
                    ),
                  ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final Json detail;

  @override
  Widget build(BuildContext context) {
    final reachable = detail['reachable'] != false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(color: NS.surface, border: Border(bottom: BorderSide(color: NS.borderMuted))),
      child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Pill(reachable ? 'reachable' : 'unreachable', color: reachable ? NS.success : NS.danger),
        if (detail['ip'] != null)
          InkWell(
            onLongPress: () => copyText(context, str(detail['ip'])),
            child: Text(str(detail['ip']), style: NS.mono.copyWith(fontSize: 13, color: NS.textSecondary)),
          ),
        if (detail['site'] != null) Text('· ${detail['site']}', style: const TextStyle(color: NS.textSecondary, fontSize: 13)),
        if (detail['platform'] != null)
          Text('· ${detail['platform']}', style: const TextStyle(color: NS.textSecondary, fontSize: 13)),
        if (detail['nurse_call'] == true) const Pill('nurse call', color: NS.orange),
        if (detail['ise_only'] == true) const Pill('ISE only', color: NS.purple),
      ]),
    );
  }
}

class _EndpointsTab extends StatefulWidget {
  const _EndpointsTab({super.key, required this.switchId});

  final String switchId;

  @override
  State<_EndpointsTab> createState() => _EndpointsTabState();
}

class _EndpointsTabState extends State<_EndpointsTab> with AutomaticKeepAliveClientMixin {
  final _rows = <Json>[];
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  String? _note;
  String? _error;
  bool _loading = false;
  String _filter = '';
  Timer? _debounce;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    _reset();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    _rows.clear();
    _page = 0;
    _pages = 1;
    _error = null;
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _pages) return;
    setState(() => _loading = true);
    final filter = _filter;
    try {
      final res = await context.read<AppState>().api.switchEndpoints(widget.switchId, page: _page + 1, filter: filter);
      if (!mounted || filter != _filter) return;
      setState(() {
        _rows.addAll(jsonList(res['results']));
        _page = res['page'] as int? ?? _page + 1;
        _pages = res['pages'] as int? ?? _page;
        _total = res['total'] as int? ?? _rows.length;
        _note = res['note'] == null ? null : str(res['note']);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _reset,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _rows.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Filter by MAC, IP, port or VLAN',
                    prefixIcon: Icon(Icons.filter_list, size: 20, color: NS.textSecondary),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () {
                      _filter = v.trim();
                      _reset();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text('$_total endpoint${_total == 1 ? '' : 's'}',
                    style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
              ]),
            );
          }
          if (i == _rows.length + 1) {
            if (_error != null) return Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: NS.danger)));
            if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Loading());
            if (_rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_note ?? 'No endpoints match.', textAlign: TextAlign.center, style: const TextStyle(color: NS.textSecondary)),
              );
            }
            return const SizedBox(height: 24);
          }
          final row = _rows[i - 1];
          final title = str(row['hostname'], str(row['mac']));
          return Column(children: [
            ListTile(
              leading: Icon(
                row['connection_type'] == 'wireless' ? Icons.wifi : Icons.settings_ethernet,
                color: freshnessColor(str(row['freshness'])),
                size: 20,
              ),
              title: Text(title, style: NS.mono.copyWith(fontSize: 13.5)),
              subtitle: Text(
                [
                  if (row['hostname'] != null) row['mac'],
                  row['ip'],
                  row['port'],
                  if (row['vlan'] != null) 'vlan ${row['vlan']}',
                  row['category'],
                ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                style: const TextStyle(color: NS.textSecondary, fontSize: 12),
              ),
              trailing: Text(ago(row['last_seen']), style: const TextStyle(color: NS.textDim, fontSize: 11.5)),
              onTap: () => openEndpoint(context, str(row['mac'])),
            ),
            const Divider(height: 1, indent: 16),
          ]);
        },
      ),
    );
  }
}

class _PortsTab extends StatefulWidget {
  const _PortsTab({super.key, required this.switchId, required this.switchName, required this.canAct});

  final String switchId;
  final String switchName;
  final bool canAct;

  @override
  State<_PortsTab> createState() => _PortsTabState();
}

class _PortsTabState extends State<_PortsTab> with AutomaticKeepAliveClientMixin {
  Json? _data;
  String? _error;
  String? _status;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppState>().api.switchPorts(widget.switchId);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final data = _data;
    if (data == null) return const Loading();
    final counts = jsonMap(data['counts']);
    final ports = jsonList(data['ports']).where((p) => _status == null || p['status'] == _status).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: [
              for (final s in ['free', 'recent', 'in_use', 'uplink'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _status == s,
                    showCheckmark: false,
                    avatar: CircleAvatar(backgroundColor: portStatusColor(s), radius: 4),
                    label: Text('${portStatusLabel(s)} ${counts[s] ?? 0}'),
                    onSelected: (on) => setState(() => _status = on ? s : null),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(str(data['note']), style: const TextStyle(color: NS.textDim, fontSize: 11.5)),
          ),
          for (final p in ports) ...[
            ListTile(
              dense: true,
              leading: Icon(Icons.circle, size: 10, color: portStatusColor(str(p['status']))),
              minLeadingWidth: 10,
              title: Row(children: [
                Text(shortPort(str(p['name'])), style: NS.mono.copyWith(fontSize: 13.5)),
                const SizedBox(width: 8),
                if (p['disabled'] == true) const Pill('shut', color: NS.danger),
                if (p['mode'] == 'access' && p['access_vlan'] != null)
                  Text('vlan ${p['access_vlan']}${p['voice_vlan'] != null ? ' / v${p['voice_vlan']}' : ''}',
                      style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
              ]),
              subtitle: Text(
                [
                  if (str(p['description']).isNotEmpty) p['description'],
                  if (p['neighbor'] != null) '→ ${p['neighbor']}',
                  if ((p['endpoints'] ?? 0) > 0) '${p['endpoints']} endpoint${p['endpoints'] == 1 ? '' : 's'}',
                  if (p['status'] != 'in_use' && p['last_active'] != null) 'active ${ago(p['last_active'])}',
                ].join(' · '),
                style: const TextStyle(color: NS.textSecondary, fontSize: 12),
              ),
              trailing: widget.canAct ? const Icon(Icons.chevron_right, size: 18) : null,
              onTap: () => showPortSheet(context,
                  switchId: widget.switchId, switchName: widget.switchName, portName: str(p['name']), port: p),
            ),
            const Divider(height: 1, indent: 16),
          ],
        ],
      ),
    );
  }
}

String shortPort(String name) {
  const map = {
    'TwentyFiveGigE': 'Twe',
    'TwentyFiveGigabitEthernet': 'Twe',
    'HundredGigE': 'Hu',
    'FortyGigabitEthernet': 'Fo',
    'TenGigabitEthernet': 'Te',
    'FiveGigabitEthernet': 'Fi',
    'TwoGigabitEthernet': 'Tw',
    'GigabitEthernet': 'Gi',
    'FastEthernet': 'Fa',
    'Ethernet': 'Et',
  };
  for (final e in map.entries) {
    if (name.startsWith(e.key)) return '${e.value}${name.substring(e.key.length)}';
  }
  return name;
}
