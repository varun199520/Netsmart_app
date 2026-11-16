import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../switch_screen.dart';
import 'tool_kit.dart';

void _openSwitch(BuildContext context, Json node) => Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => SwitchScreen(switchId: str(node['id']), initialName: str(node['name']))));

String _window(dynamic start, dynamic end) {
  final s = parseTime(start), e = parseTime(end);
  if (s == null) return '—';
  final day = DateFormat('EEE MMM d');
  final time = DateFormat('HH:mm');
  if (e == null) return '${day.format(s)} ${time.format(s)}';
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  return sameDay
      ? '${day.format(s)} · ${time.format(s)}–${time.format(e)}'
      : '${day.format(s)} ${time.format(s)} → ${day.format(e)} ${time.format(e)}';
}

// ── Change Requests ─────────────────────────────────────────────────────────

class ChangeRequestsScreen extends StatefulWidget {
  const ChangeRequestsScreen({super.key});

  @override
  State<ChangeRequestsScreen> createState() => _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends State<ChangeRequestsScreen> {
  Key _bodyKey = UniqueKey();
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await context.read<AppState>().api.changeRequests(refresh: true);
      if (mounted) setState(() => _bodyKey = UniqueKey());
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Requests'), actions: [
        IconButton(
          tooltip: 'Sync latest changes',
          onPressed: _syncing ? null : _sync,
          icon: _syncing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
        ),
      ]),
      body: AsyncBody<Json>(
        key: _bodyKey,
        load: () => api.changeRequests(),
        builder: (context, data, _) {
          final inProgress = jsonList(data['in_progress']);
          final scheduled = jsonList(data['scheduled']);
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (str(data['error']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(str(data['error']), style: const TextStyle(color: NS.warning, fontSize: 13)),
              ),
            if (data['last_synced'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Synced ${ago(data['last_synced'])}',
                    style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
              ),
            _heading('In progress', inProgress.length, NS.warning),
            if (inProgress.isEmpty) noResults('Nothing in progress.'),
            for (final c in inProgress) _ChangeCard(change: c, active: true),
            const SizedBox(height: 8),
            _heading('Scheduled', scheduled.length, NS.accent),
            if (scheduled.isEmpty) noResults('No scheduled changes.'),
            for (final c in scheduled) _ChangeCard(change: c),
          ]);
        },
      ),
    );
  }

  Widget _heading(String title, int count, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: const TextStyle(color: NS.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(width: 6),
          Text('$count', style: const TextStyle(color: NS.textDim, fontSize: 11)),
        ]),
      );
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.change, this.active = false});

  final Json change;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = change;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => ChangeDetailScreen(sysId: str(c['sys_id']), number: str(c['number'])))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(str(c['number']), style: NS.mono.copyWith(fontSize: 13, color: NS.accent, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Pill(str(c['change_type'], 'Change'),
                        color: str(c['change_type']).toLowerCase() == 'emergency' ? NS.danger : NS.textSecondary),
                  ]),
                  const SizedBox(height: 6),
                  Text(str(c['short_description']), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    active && c['work_start'] != null
                        ? 'Started ${ago(c['work_start'])} · ends ${_window(c['planned_end'], null)}'
                        : _window(c['planned_start'], c['planned_end']),
                    style: const TextStyle(color: NS.textSecondary, fontSize: 12.5),
                  ),
                  if (c['outage_start'] != null)
                    Text('Outage ${_window(c['outage_start'], c['outage_end'])}',
                        style: const TextStyle(color: NS.danger, fontSize: 12.5)),
                  if (str(c['assigned_to']).isNotEmpty)
                    Text(str(c['assigned_to']), style: const TextStyle(color: NS.textDim, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: NS.textDim),
            ]),
          ),
        ),
      ),
    );
  }
}

class ChangeDetailScreen extends StatelessWidget {
  const ChangeDetailScreen({super.key, required this.sysId, required this.number});

  final String sysId;
  final String number;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: Text(number)),
      body: AsyncBody<Json>(
        load: () => api.changeRequest(sysId),
        builder: (context, data, _) {
          final c = jsonMap(data['change']);
          final tasks = jsonList(data['tasks']);
          final cis = (data['affected_cis'] as List? ?? const []).map((e) => '$e').toList();
          final notes = str(data['work_notes']);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(str(c['short_description']), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (str(c['state_label']).isNotEmpty) Pill(str(c['state_label']), color: NS.accent),
              if (str(c['change_type']).isNotEmpty) Pill(str(c['change_type'])),
              if (str(c['risk']).isNotEmpty) Pill('Risk ${str(c['risk'])}', color: NS.warning),
            ]),
            const SizedBox(height: 14),
            SectionCard(title: 'Schedule', children: [
              KV('Planned', _window(c['planned_start'], c['planned_end'])),
              if (c['outage_start'] != null) KV('Outage', _window(c['outage_start'], c['outage_end']), valueColor: NS.danger),
              if (c['work_start'] != null) KV('Work started', stamp(c['work_start'])),
              if (c['work_end'] != null) KV('Work ended', stamp(c['work_end'])),
            ]),
            const SizedBox(height: 12),
            SectionCard(title: 'Details', children: [
              KV('Assigned to', str(c['assigned_to'])),
              KV('Priority', str(c['priority'])),
              if (str(c['description']).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(str(c['description']), style: const TextStyle(color: NS.text, fontSize: 13.5, height: 1.4)),
              ],
            ]),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(title: 'Tasks', children: [
                for (final t in tasks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(str(t['short_description']), style: const TextStyle(fontSize: 13.5)),
                          Text('${str(t['number'])} · ${str(t['assignment_group'])}',
                              style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
                        ]),
                      ),
                      Pill(str(t['state'])),
                    ]),
                  ),
              ]),
            ],
            if (cis.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(title: 'Affected devices', children: [
                Wrap(spacing: 6, runSpacing: 6, children: [for (final ci in cis) Pill(ci, color: NS.cyan)]),
              ]),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(title: 'Work notes', children: [
                Text(notes, style: const TextStyle(color: NS.text, fontSize: 13, height: 1.4)),
              ]),
            ],
          ]);
        },
      ),
    );
  }
}

// ── Team Calendar ───────────────────────────────────────────────────────────

Color _eventColor(String type) => switch (type) {
      'pto' => NS.orange,
      'oncall' => NS.purple,
      'travel' => NS.cyan,
      'wfh' => NS.accent,
      _ => NS.textSecondary,
    };

class TeamCalendarScreen extends StatelessWidget {
  const TeamCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Scaffold(
      appBar: AppBar(title: const Text('Team Calendar')),
      body: AsyncBody<List<Json>>(
        load: () => api.calendarEvents(today, today.add(const Duration(days: 45))),
        builder: (context, events, _) {
          DateTime d(dynamic v) => DateTime.tryParse(str(v)) ?? today;
          final current = events.where((e) => !d(e['start_date']).isAfter(today) && !d(e['end_date']).isBefore(today)).toList();
          final upcoming = events.where((e) => d(e['start_date']).isAfter(today)).toList()
            ..sort((a, b) => d(a['start_date']).compareTo(d(b['start_date'])));
          final byDay = <DateTime, List<Json>>{};
          for (final e in upcoming) {
            byDay.putIfAbsent(d(e['start_date']), () => []).add(e);
          }
          final dayFmt = DateFormat('EEEE, MMM d');
          return ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(title: 'Today · ${DateFormat('MMM d').format(today)}', children: [
              if (current.isEmpty) const Text('Everyone is in.', style: TextStyle(color: NS.textSecondary)),
              for (final e in current) _EventRow(event: e),
            ]),
            const SizedBox(height: 16),
            if (byDay.isEmpty) noResults('Nothing else in the next 45 days.'),
            for (final entry in byDay.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
                child: Text(dayFmt.format(entry.key),
                    style: const TextStyle(color: NS.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(children: [for (final e in entry.value) _EventRow(event: e)]),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ]);
        },
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final Json event;

  @override
  Widget build(BuildContext context) {
    final type = str(event['type']);
    final color = _eventColor(type);
    final fmt = DateFormat('MMM d');
    final start = DateTime.tryParse(str(event['start_date']));
    final end = DateTime.tryParse(str(event['end_date']));
    final range = start == null
        ? ''
        : (end == null || end == start ? fmt.format(start) : '${fmt.format(start)} – ${fmt.format(end)}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(width: 4, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(str(event['name'], str(event['username'])), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text([str(event['title']), range].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
          ]),
        ),
        Pill(str(event['type_label'], type), color: color),
      ]),
    );
  }
}

// ── Nurse Call Switches ─────────────────────────────────────────────────────

class NurseCallScreen extends StatelessWidget {
  const NurseCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Nurse Call Switches')),
      body: AsyncBody<Json>(
        load: api.nurseCallSwitches,
        builder: (context, data, _) {
          final rows = jsonList(data['results']);
          final total = rows.length;
          final up = rows.where((r) => r['reachable'] == true).length;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: _Stat(label: 'Switches', value: '$total', color: NS.accent)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Reachable', value: '$up', color: NS.success)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Down', value: '${total - up}', color: total - up > 0 ? NS.danger : NS.textSecondary)),
            ]),
            const SizedBox(height: 14),
            Card(
              child: Column(children: [
                for (final (i, r) in rows.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  _NodeTile(node: r, trailing: '${str(r['access_ports'], '0')} ports'),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
          ]),
        ),
      );
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node, this.trailing});

  final Json node;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final up = node['reachable'] == true;
    final sub = [node['ip'], node['location']].where((v) => v != null && '$v'.isNotEmpty).join(' · ');
    return ListTile(
      leading: Icon(Icons.circle, size: 10, color: up ? NS.success : NS.danger),
      minLeadingWidth: 10,
      title: Text(str(node['name']), style: NS.mono.copyWith(fontSize: 14)),
      subtitle: sub.isEmpty ? null : Text(sub, style: NS.mono.copyWith(color: NS.textSecondary, fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) Text(trailing!, style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
        const Icon(Icons.chevron_right, color: NS.textDim),
      ]),
      onTap: () => _openSwitch(context, node),
    );
  }
}

// ── Site Locations ──────────────────────────────────────────────────────────

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  final _filter = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Site Locations')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _filter,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Filter sites', prefixIcon: Icon(Icons.search, color: NS.textSecondary)),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        Expanded(
          child: AsyncBody<List<Json>>(
            key: ValueKey(_query),
            load: () => api.sites(_query),
            builder: (context, sites, _) => sites.isEmpty
                ? ListView(children: [noResults('  No sites match.')])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                    itemCount: sites.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final s = sites[i];
                      return ListTile(
                        leading: const Icon(Icons.location_city_outlined),
                        title: Text(str(s['name'])),
                        subtitle: Text([s['site_type'], s['address']].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                            style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${str(s['devices'], '0')} devices',
                              style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
                          const Icon(Icons.chevron_right, color: NS.textDim),
                        ]),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => SiteScreen(siteId: str(s['id']), name: str(s['name'])))),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class SiteScreen extends StatelessWidget {
  const SiteScreen({super.key, required this.siteId, required this.name});

  final String siteId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: AsyncBody<Json>(
        load: () => api.site(siteId),
        builder: (context, data, _) {
          final site = jsonMap(data['site']);
          final nodes = jsonList(data['nodes']);
          final down = nodes.where((n) => n['reachable'] != true).length;
          return ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(children: [
              KV('Type', str(site['site_type'])),
              KV('Address', str(site['address'])),
              KV('Devices', '${nodes.length}'),
              if (down > 0) KV('Unreachable', '$down', valueColor: NS.danger),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                for (final (i, n) in nodes.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  _NodeTile(node: n, trailing: str(n['role'])),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
