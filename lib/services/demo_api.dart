import 'dart:async';
import 'dart:math';

import 'api.dart';

/// Offline sample data so the app can be explored without a NetSmart account
/// (App Review, demos). Nothing here touches the network.
class DemoApi implements NetsmartApi {
  DemoApi() {
    _ports = _buildPorts();
    _endpoints = _buildEndpoints();
  }

  static const switchId = '00000000-0000-4000-8000-000000000001';
  static const switchName = 'DEMO-ACC-SW01';

  late final List<Json> _ports;
  late final List<Json> _endpoints;
  final Map<String, Json> _jobs = {};
  final Map<String, DateTime> _jobStarted = {};
  final List<Json> _reservations = [
    {'ip': '192.0.2.40', 'mac': '00:1b:63:84:45:e6', 'name': 'lab-printer-01', 'comment': 'Demo reservation', 'network': '192.0.2.0/24', 'servers': ['Primary', 'Secondary'], 'missing': <String>[]},
    {'ip': '192.0.2.41', 'mac': '3c:22:fb:10:aa:02', 'name': 'badge-reader-02', 'comment': '', 'network': '192.0.2.0/24', 'servers': ['Primary'], 'missing': ['Secondary']},
  ];
  final List<Json> _chatSessions = [];
  final Map<String, List<Json>> _chatHistory = {};
  int _seq = 0;

  @override
  bool get isDemo => true;

  Future<T> _delay<T>(T value) => Future.delayed(const Duration(milliseconds: 350), () => value);

  Json get _switch => {
        'id': switchId,
        'name': switchName,
        'ip': '192.0.2.10',
        'site': 'Demo Campus',
        'platform': 'cisco_ios',
        'role': 'access',
        'reachable': true,
      };

  List<Json> _buildPorts() {
    final rnd = Random(7);
    final ports = <Json>[];
    for (var i = 1; i <= 24; i++) {
      final status = i > 22 ? 'uplink' : (i % 5 == 0 ? 'free' : (i % 7 == 0 ? 'recent' : 'in_use'));
      ports.add({
        'name': 'GigabitEthernet1/0/$i',
        'description': status == 'uplink' ? 'to DEMO-DIST-01' : (status == 'free' ? '' : 'Room ${100 + i}'),
        'admin_status': 'up',
        'oper_status': status == 'in_use' || status == 'uplink' ? 'up' : 'down',
        'mode': status == 'uplink' ? 'trunk' : 'access',
        'access_vlan': status == 'uplink' ? null : (i.isEven ? 20 : 30),
        'voice_vlan': i.isEven ? 40 : null,
        'status': status,
        'disabled': false,
        'last_active': status == 'free' ? null : DateTime.now().subtract(Duration(hours: rnd.nextInt(90))).toIso8601String(),
        'endpoints': status == 'in_use' ? 1 + rnd.nextInt(2) : 0,
        'neighbor': status == 'uplink' ? 'DEMO-DIST-01' : null,
      });
    }
    return ports;
  }

  List<Json> _buildEndpoints() {
    const kinds = [
      ('Workstation', 'Dell Inc.'),
      ('IP Phone', 'Cisco Systems'),
      ('Printer', 'HP Inc.'),
      ('Badge Reader', 'HID Global'),
      ('Infusion Pump', 'Baxter'),
    ];
    final out = <Json>[];
    var n = 0;
    for (final port in _ports.where((p) => p['status'] == 'in_use')) {
      for (var k = 0; k < (port['endpoints'] as int); k++) {
        final kind = kinds[n % kinds.length];
        final mac = _mac(n);
        out.add({
          'mac': mac,
          'ip': '192.0.2.${100 + n}',
          'port': (port['name'] as String).replaceFirst('GigabitEthernet', 'Gi'),
          'vlan': k == 1 ? '40' : '${port['access_vlan']}',
          'hostname': '${kind.$1.toLowerCase().replaceAll(' ', '-')}-${n.toString().padLeft(2, '0')}',
          'category': kind.$1,
          'owner': 'Demo Department',
          'vendor': kind.$2,
          'connection_type': 'wired',
          'last_seen': DateTime.now().subtract(Duration(minutes: 3 + n * 7)).toIso8601String(),
          'freshness': n % 6 == 5 ? 'stale' : 'fresh',
        });
        n++;
      }
    }
    return out;
  }

  static String _mac(int n) {
    final b = [0x00, 0x1b, 0x63, 0x10 + n ~/ 256, n % 256, 0x5a];
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(':');
  }

  @override
  Future<Json> me() => _delay({
        'username': 'demo',
        'name': 'Demo User',
        'email': '',
        'session_id': 'demo',
        'push_enabled': false,
        'capabilities': {
          'tracker': true,
          'chat': true,
          'switch_read': true,
          'bounce': true,
          'configure': true,
          'ise_removal': true,
          'dhcp': true,
        },
      });

  @override
  Future<Json> search(String query) async {
    final q = query.trim().toLowerCase();
    final match = _endpoints.firstWhere(
      (e) => e['mac'] == q || e['ip'] == q || (e['hostname'] as String).contains(q),
      orElse: () => _endpoints.first,
    );
    final port = _ports.firstWhere((p) => (p['name'] as String).endsWith((match['port'] as String).substring(2)));
    return _delay({
      'ok': true,
      'found': true,
      'query': query,
      'query_type': q.contains(':') ? 'mac' : (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(q) ? 'ip' : 'hostname'),
      'message': 'Demo data — sample endpoint.',
      'resolved': null,
      'freshness': {'state': match['freshness'], 'last_seen': match['last_seen'], 'age_minutes': 12},
      'connection': 'wired',
      'identity': {
        'hostname': match['hostname'],
        'category': match['category'],
        'owner': match['owner'],
        'vendor': match['vendor'],
      },
      'mac': match['mac'],
      'ips': [match['ip']],
      'wired': {
        'switch': switchName,
        'switch_id': switchId,
        'port': port['name'],
        'vlan': match['vlan'],
        'port_mode': 'access',
        'access_vlan': port['access_vlan'],
        'voice_vlan': port['voice_vlan'],
        'other_macs_on_port': (port['endpoints'] as int) - 1,
        'port_interpretation': (port['endpoints'] as int) > 1 ? 'Phone with a PC behind it' : 'Single endpoint',
        'link_state': 'up',
        'first_seen': DateTime.now().subtract(const Duration(days: 21)).toIso8601String(),
        'last_seen': match['last_seen'],
      },
      'gateway': {'device': 'DEMO-DIST-01', 'interface': 'Vlan${port['access_vlan']}', 'address': '192.0.2.1/24', 'vrf': null},
      'wireless': <Json>[],
      'recent_moves': <Json>[],
      'warnings': <String>[],
    });
  }

  @override
  Future<List<Json>> switches(String query) async =>
      _delay(query.trim().length < 2 || !switchName.toLowerCase().contains(query.trim().toLowerCase()) && !'192.0.2.10'.contains(query.trim())
          ? <Json>[]
          : [_switch]);

  @override
  Future<Json> switchDetail(String id) => _delay({
        ..._switch,
        'nurse_call': false,
        'ise_only': false,
        'actions': {'read': true, 'bounce': true, 'configure': true, 'ise_removal': true},
        'dhcp': true,
      });

  @override
  Future<Json> switchEndpoints(String id, {int page = 1, int pageSize = 50, String sort = 'last_seen', String filter = ''}) {
    final f = filter.toLowerCase();
    final rows = _endpoints
        .where((e) => f.isEmpty || [e['mac'], e['ip'], e['port'], e['vlan']].any((v) => '$v'.toLowerCase().contains(f)))
        .toList();
    final start = (page - 1) * pageSize;
    return _delay({
      'ok': true,
      'switch': _switch,
      'source': 'demo',
      'total': rows.length,
      'page': page,
      'pages': max(1, (rows.length / pageSize).ceil()),
      'page_size': pageSize,
      'results': rows.skip(start).take(pageSize).toList(),
    });
  }

  @override
  Future<Json> switchPorts(String id) {
    final counts = <String, int>{'free': 0, 'recent': 0, 'in_use': 0, 'uplink': 0, 'unknown': 0};
    for (final p in _ports) {
      counts[p['status'] as String] = counts[p['status']]! + 1;
    }
    return _delay({
      'history_from': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      'history_days': 7.0,
      'counts': counts,
      'ports': _ports,
      'note': 'Free = link down and no endpoint seen since history_from.',
    });
  }

  @override
  Future<List<Json>> switchVlans(String id) => _delay([
        {'vlan': 20, 'name': 'DATA', 'suspended': false},
        {'vlan': 30, 'name': 'CLINICAL', 'suspended': false},
        {'vlan': 40, 'name': 'VOICE', 'suspended': false},
        {'vlan': 99, 'name': 'PARKING', 'suspended': true},
      ]);

  Json _refreshJob(String status) => {
        'job_uuid': 'demo-refresh',
        'switch': switchName,
        'status': status,
        'trigger': 'user',
        'created_at': DateTime.now().toIso8601String(),
        'started_at': null,
        'finished_at': status == 'success' ? DateTime.now().toIso8601String() : null,
        'error': null,
        'mac_rows': status == 'success' ? _endpoints.length : null,
        'arp_rows': status == 'success' ? _endpoints.length : null,
        'locations_updated': status == 'success' ? 2 : null,
      };

  DateTime? _refreshAt;

  @override
  Future<Json> refreshSwitch(String id) {
    _refreshAt = DateTime.now();
    return _delay({'reason': 'queued', 'job': _refreshJob('pending')});
  }

  @override
  Future<Json> refreshStatus(String id, String jobId) {
    final done = _refreshAt == null || DateTime.now().difference(_refreshAt!).inSeconds >= 3;
    return _delay(_refreshJob(done ? 'success' : 'running'));
  }

  @override
  Future<Json> submitJob(Json body) async {
    final kind = str(body['kind']);
    final id = 'demo-job-${++_seq}';
    final port = str(body['port']);
    final target = switch (kind) {
      'dhcp_reserve' => '${body['mac']} ${body['ip'] ?? body['subnet']}',
      'ping' => '${body['ip']} (${body['vrf']})',
      'port_usage' => switchName,
      _ => '$switchName $port',
    };
    _jobStarted[id] = DateTime.now();
    _jobs[id] = {
      'id': id,
      'kind': kind,
      'status': 'queued',
      'done': false,
      'target': target,
      'switch': (kind == 'dhcp_reserve' && body['switch_id'] == null) || kind == 'ping'
          ? null
          : {'id': switchId, 'name': switchName},
      'params': Json.from(body)..remove('kind'),
      'result': null,
      'message': '',
      'created_at': DateTime.now().toIso8601String(),
      'started_at': null,
      'finished_at': null,
    };
    return _delay(_jobs[id]!);
  }

  @override
  Future<Json> job(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) throw ApiException('Not found.', status: 404);
    final age = DateTime.now().difference(_jobStarted[jobId]!).inMilliseconds;
    if (!job['done'] && age > 1200) job['status'] = 'running';
    if (!job['done'] && age > 3500) {
      job
        ..['status'] = 'succeeded'
        ..['done'] = true
        ..['finished_at'] = DateTime.now().toIso8601String()
        ..['result'] = _result(job);
      if (job['kind'] == 'dhcp_reserve') {
        final r = jsonMap(job['result']);
        _reservations.add({
          'ip': r['ip'], 'mac': r['mac'], 'name': r['name'], 'comment': '',
          'network': '192.0.2.0/24', 'servers': ['Primary', 'Secondary'], 'missing': <String>[],
        });
      }
    }
    return _delay(Json.from(job));
  }

  Json _result(Json job) {
    final params = jsonMap(job['params']);
    final port = str(params['port']);
    switch (job['kind']) {
      case 'port_read':
        final p = _ports.firstWhere((x) => x['name'] == port, orElse: () => _ports.first);
        return {
          'port': port,
          'description': p['description'],
          'access_vlan': '${p['access_vlan'] ?? ''}',
          'voice_vlan': p['voice_vlan'] == null ? null : '${p['voice_vlan']}',
          'mode': p['mode'],
          'admin_down': false,
          'oper_status': p['oper_status'],
          'config': 'interface $port\n description ${p['description']}\n switchport mode access\n'
              ' switchport access vlan ${p['access_vlan'] ?? 1}\n spanning-tree portfast',
        };
      case 'bounce':
        return {'port': port, 'status': 'success', 'detail': 'Port shut and re-enabled. Link came back up.', 'oper_status': 'up'};
      case 'port_config':
      case 'ise_removal':
        return {
          'port': port,
          'status': 'success',
          'detail': job['kind'] == 'ise_removal' ? 'ISE authentication removed; it will be restored automatically.' : 'Configuration applied and saved.',
          'vlan': params['vlan'],
          'voice': params['add_voice'] == true ? '40' : '',
          'description': params['description'],
          'oper_status': 'up',
          'saved': true,
          'revert_due_at': job['kind'] == 'ise_removal' ? DateTime.now().add(const Duration(hours: 4)).toIso8601String() : null,
        };
      case 'ping':
        final ip = str(params['ip']);
        return {
          'status': 'success',
          'switch': switchName,
          'ip': ip,
          'vrf': params['vrf'],
          'success_rate': 100,
          'output': 'Type escape sequence to abort.\n'
              'Sending 10, 100-byte ICMP Echos to $ip, timeout is 2 seconds:\n'
              '!!!!!!!!!!\n'
              'Success rate is 100 percent (10/10), round-trip min/avg/max = 1/1/3 ms',
        };
      case 'port_usage':
        final unused = _ports.where((p) => p['status'] == 'free').toList();
        return {
          'status': 'success',
          'switch': switchName,
          'uptime': '12 weeks, 3 days, 4 hours',
          'total': 22,
          'used': 22 - unused.length,
          'unused': unused.length,
          'used_pct': ((22 - unused.length) * 100 / 22).round(),
          'unused_pct': (unused.length * 100 / 22).round(),
          'unused_ports': [
            for (final p in unused)
              {'interface': p['name'], 'link_status': 'down', 'last_input': 'never', 'description': p['description']},
          ],
        };
      default:
        final ip = params['ip'] ?? '192.0.2.${60 + _seq}';
        return {
          'status': 'success',
          'ip': ip,
          'mac': params['mac'],
          'name': params['name'],
          'fqdn': null,
          'servers': [
            {'server': 'Primary', 'ok': true, 'noop': false, 'detail': 'created'},
            {'server': 'Secondary', 'ok': true, 'noop': false, 'detail': 'created'},
          ],
        };
    }
  }

  @override
  Future<List<Json>> jobs() async {
    for (final id in _jobs.keys.toList()) {
      await job(id);
    }
    return _jobs.values.toList().reversed.map(Json.from).toList();
  }

  @override
  Future<Json> dhcpSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) throw ApiException("'' doesn't look like a MAC or IP address.");
    final normalized = q.replaceAll(RegExp(r'[^0-9a-f.]'), '');
    final rows = _reservations
        .where((r) => r['ip'] == q || str(r['mac']).replaceAll(':', '') == normalized.replaceAll('.', ''))
        .toList();
    return _delay({
      'query': query,
      'kind': q.contains('.') && !q.contains(':') ? 'ip' : 'mac',
      'results': rows,
      'servers': ['Primary', 'Secondary'],
      'errors': <String>[],
    });
  }

  @override
  Future<List<Json>> dhcpSubnets(String switchId) => _delay([
        {'vlan': 20, 'subnet': '192.0.2.0/24', 'description': 'DATA'},
        {'vlan': 30, 'subnet': '198.51.100.0/24', 'description': 'CLINICAL'},
      ]);

  @override
  Future<List<Json>> chatSessions() => _delay(List<Json>.from(_chatSessions));

  @override
  Future<Json> createChatSession() async {
    final s = {'id': 'demo-chat-${++_seq}', 'name': 'New Session', 'created_at': DateTime.now().toIso8601String()};
    _chatSessions.insert(0, s);
    _chatHistory[s['id']!] = [];
    return _delay(s);
  }

  @override
  Future<void> deleteChatSession(String sessionId) async {
    _chatSessions.removeWhere((s) => s['id'] == sessionId);
    _chatHistory.remove(sessionId);
  }

  @override
  Future<Json> chatHistory(String sessionId) {
    final s = _chatSessions.firstWhere((s) => s['id'] == sessionId, orElse: () => {'name': 'Session'});
    return _delay({'id': sessionId, 'name': s['name'], 'results': _chatHistory[sessionId] ?? <Json>[]});
  }

  @override
  Future<List<Json>> chatModels() => _delay([
        {'id': 'demo-default', 'label': 'Default model', 'provider': 'demo', 'custom': false},
      ]);

  @override
  Future<ChatConnection> openChat() async => _DemoChat(this);

  // ── web navigation + native tools ────────────────────────────────────────

  static Json _item(String title, String path, [String? native]) =>
      {'title': title, 'path': path, 'native': ?native};

  @override
  Future<Json> navigation() => _delay({
        'sections': [
          {
            'title': 'AI & Automation',
            'accent': 'ai',
            'groups': [
              {
                'label': 'AI Assistant',
                'icon': 'bxs-brain',
                'items': [_item('NetSmart AI', '/netsmart-chat/', 'chat'), _item('My Memory', '/settings/my_memory/')],
              },
            ],
          },
          {
            'title': 'Network Operations',
            'accent': 'network',
            'groups': [
              {
                'label': 'Node & Device',
                'icon': 'bxs-devices',
                'items': [_item('Device Tracker', '/deviceTracker/', 'tracker'), _item('Config Changes', '/node_manager/config-changes/')],
              },
              {
                'label': 'Switch Management',
                'icon': 'bx-chip',
                'items': [
                  _item('Ping from Switch', '/switchport_config/ping/', 'ping'),
                  _item('Available Switchports', '/switchport_stat/', 'port_usage'),
                  _item('Nurse Call Switches', '/switchport_config/nurse_call_switches/', 'nurse_call'),
                  _item('Site Locations', '/switchport_stat/site_locations/', 'site_locations'),
                ],
              },
              {
                'label': 'DC Fabric & VRF',
                'icon': 'bx-server',
                'items': [_item('DC Fabric VLAN Tracker', '/dc_fabric/dc_vlan_search', 'dc_vlans')],
              },
            ],
          },
          {
            'title': 'Security & Access',
            'accent': 'security',
            'groups': [
              {
                'label': 'DNS & IP Management',
                'icon': 'fa-circle-nodes',
                'items': [
                  _item('DNS Lookup', '/dhcp/record_lookup/', 'dns_lookup'),
                  _item('IP Reservations', '/dhcp/', 'dhcp'),
                  _item('DHCP IP/MAC Lookup', '/dhcp/ip_info/', 'ip_mac_lookup'),
                  _item('Subnet Lookup', '/dhcp/ip_lookup/', 'subnet_lookup'),
                  _item('Subnet Calculator', '/dhcp/subnet_calculator/', 'subnet_calculator'),
                ],
              },
            ],
          },
          {
            'title': 'Integrations',
            'accent': 'integr',
            'groups': [
              {
                'label': 'Change Management',
                'icon': 'bx-calendar-check',
                'items': [_item('Change Requests', '/cr_view/', 'change_requests')],
              },
            ],
          },
          {
            'title': 'Inventory Management',
            'accent': 'integr',
            'groups': [
              {
                'label': 'NetSmart DCM',
                'icon': 'bx-data',
                'items': [
                  {'title': 'NetSmart DCM', 'url': 'https://netsmart-dcm.stanfordmed.org/', 'external': true},
                ],
              },
            ],
          },
          {
            'title': 'IT Operations',
            'accent': 'itops',
            'groups': [
              {
                'label': 'Team Calendar',
                'icon': 'bx-calendar',
                'items': [_item('Team Calendar', '/team-calendar/', 'team_calendar')],
              },
            ],
          },
          {
            'title': 'Documentation',
            'accent': 'content',
            'groups': [
              {
                'label': 'Guides',
                'icon': 'bxs-book-open',
                'items': [_item('User Guide', '/docs/user-guide/')],
              },
            ],
          },
        ],
      });

  @override
  Future<Json> webSession(String path) async =>
      throw ApiException('This page opens the NetSmart website, which needs a real sign-in. '
          'Demo mode only includes the native screens.', code: 'demo');

  static const _dcVlans = [
    {'vlan': 210, 'name': 'APP-WEB', 'subnet': '192.0.2.0/26', 'vrf': 'APP', 'dc': 'DC-A', 'switch': 'DEMO-DC-LEAF01', 'switch_ip': '198.51.100.11'},
    {'vlan': 210, 'name': 'APP-WEB', 'subnet': '192.0.2.0/26', 'vrf': 'APP', 'dc': 'DC-A', 'switch': 'DEMO-DC-LEAF02', 'switch_ip': '198.51.100.12'},
    {'vlan': 220, 'name': 'APP-DB', 'subnet': '192.0.2.64/26', 'vrf': 'APP', 'dc': 'DC-A', 'switch': 'DEMO-DC-LEAF01', 'switch_ip': '198.51.100.11'},
    {'vlan': 310, 'name': 'MGMT', 'subnet': '198.51.100.0/25', 'vrf': 'MGMT', 'dc': 'DC-B', 'switch': 'DEMO-DC-LEAF03', 'switch_ip': '198.51.100.13'},
  ];

  @override
  Future<Json> dcVlans(Map<String, String> filters) {
    bool keep(Map<String, Object> v) => filters.entries.every((f) {
          final q = f.value.trim().toLowerCase();
          if (q.isEmpty) return true;
          return switch (f.key) {
            'vlan' => '${v['vlan']}' == q,
            'switch' => '${v['switch']}'.toLowerCase().contains(q),
            'ip' => '${v['subnet']}'.startsWith(q.split('/').first.split('.').take(3).join('.')),
            _ => '${v[f.key]}'.toLowerCase().contains(q),
          };
        });
    final rows = _dcVlans.where(keep).map(Json.from).toList();
    return _delay({'count': rows.length, 'results': rows});
  }

  Json _change(String n, String desc, String type, int startHours, int lengthHours, {bool started = false}) {
    final start = DateTime.now().add(Duration(hours: startHours));
    return {
      'sys_id': 'demo-$n',
      'number': n,
      'short_description': desc,
      'change_type': type,
      'assigned_to': 'Demo User',
      'state': started ? 'Implement' : 'Scheduled',
      'planned_start': start.toIso8601String(),
      'planned_end': start.add(Duration(hours: lengthHours)).toIso8601String(),
      'outage_start': null,
      'outage_end': null,
      'work_start': started ? DateTime.now().subtract(const Duration(minutes: 40)).toIso8601String() : null,
    };
  }

  @override
  Future<Json> changeRequests({bool refresh = false}) => _delay({
        'ok': true,
        'error': null,
        'last_synced': DateTime.now().subtract(const Duration(minutes: 9)).toIso8601String(),
        'in_progress': [_change('CHG0010001', 'Replace access switch in demo closet', 'Normal', -1, 3, started: true)],
        'scheduled': [
          _change('CHG0010002', 'Upgrade distribution pair firmware', 'Normal', 26, 4),
          _change('CHG0010003', 'Add VLAN 30 to demo trunk', 'Standard', 50, 1),
        ],
      });

  @override
  Future<Json> changeRequest(String sysId) async {
    final all = [...jsonList((await changeRequests())['in_progress']), ...jsonList((await changeRequests())['scheduled'])];
    final c = all.firstWhere((c) => c['sys_id'] == sysId, orElse: () => all.first);
    return _delay({
      'change': {...c, 'description': '${c['short_description']}. Sample change for demo mode.', 'risk': 'Low', 'priority': '4 - Low', 'state_label': c['state']},
      'tasks': [
        {'number': 'CTASK0020001', 'short_description': 'Pre-checks', 'state': 'Closed', 'assignment_group': 'Network', 'assigned_to': 'Demo User'},
        {'number': 'CTASK0020002', 'short_description': 'Implementation', 'state': 'Open', 'assignment_group': 'Network', 'assigned_to': 'Demo User'},
      ],
      'affected_cis': [switchName, 'DEMO-DIST-01'],
      'work_notes': 'Demo work note: pre-checks complete.',
    });
  }

  @override
  Future<List<Json>> calendarEvents(DateTime from, DateTime to) {
    final today = DateTime.now();
    String d(int offset) => DateTime(today.year, today.month, today.day + offset).toIso8601String().substring(0, 10);
    return _delay([
      {'id': 'e1', 'username': 'demo', 'name': 'Demo User', 'type': 'oncall', 'type_label': 'On-call', 'title': 'On-call', 'start_date': d(-2), 'end_date': d(4)},
      {'id': 'e2', 'username': 'alex', 'name': 'Alex Sample', 'type': 'pto', 'type_label': 'PTO', 'title': 'Vacation', 'start_date': d(0), 'end_date': d(2)},
      {'id': 'e3', 'username': 'sam', 'name': 'Sam Example', 'type': 'wfh', 'type_label': 'Work from home', 'title': 'WFH', 'start_date': d(1), 'end_date': d(1)},
      {'id': 'e4', 'username': 'kim', 'name': 'Kim Placeholder', 'type': 'travel', 'type_label': 'Travel', 'title': 'Site visit', 'start_date': d(6), 'end_date': d(8)},
    ]);
  }

  @override
  Future<Json> nurseCallSwitches() => _delay({
        'total': 2,
        'reachable': 1,
        'results': [
          {'id': switchId, 'name': 'DEMO-NCF-SW01', 'ip': '192.0.2.20', 'reachable': true, 'access_ports': 24},
          {'id': '00000000-0000-4000-8000-000000000002', 'name': 'DEMO-NCF-SW02', 'ip': '192.0.2.21', 'reachable': false, 'access_ports': 48},
        ],
      });

  static const _sites = [
    {'id': '1', 'name': 'Demo Campus', 'site_type': 'Campus', 'address': '1 Example Way', 'devices': 3},
    {'id': '2', 'name': 'Demo Clinic', 'site_type': 'Clinic', 'address': '200 Sample St', 'devices': 1},
  ];

  @override
  Future<List<Json>> sites(String query) => _delay(_sites
      .where((s) => query.isEmpty || '${s['name']}'.toLowerCase().contains(query.toLowerCase()))
      .map(Json.from)
      .toList());

  @override
  Future<Json> site(String siteId) {
    final s = _sites.firstWhere((s) => s['id'] == siteId, orElse: () => _sites.first);
    return _delay({
      'site': Json.from(s),
      'nodes': [
        {'id': switchId, 'name': switchName, 'ip': '192.0.2.10', 'location': 'Closet 1A', 'reachable': true, 'role': 'access'},
        if (s['id'] == '1') ...[
          {'id': '00000000-0000-4000-8000-000000000003', 'name': 'DEMO-DIST-01', 'ip': '192.0.2.2', 'location': 'MDF', 'reachable': true, 'role': 'distribution'},
          {'id': '00000000-0000-4000-8000-000000000004', 'name': 'DEMO-ACC-SW02', 'ip': '192.0.2.11', 'location': 'Closet 2B', 'reachable': false, 'role': 'access'},
        ],
      ],
    });
  }

  @override
  Future<Json> dnsLookup(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) throw ApiException('Enter a hostname or IP address.');
    final isIp = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(q);
    final host = isIp ? 'workstation-00.demo.example' : (q.contains('.') ? q : '$q.demo.example');
    final ip = isIp ? q : '192.0.2.100';
    return _delay({
      'query': query,
      'records': [
        {'rtype': 'A', 'name': host, 'target': ip, 'servers': ['Primary', 'Secondary'], 'missing': <String>[]},
        {'rtype': 'PTR', 'name': '${ip.split('.').reversed.join('.')}.in-addr.arpa', 'target': host, 'servers': ['Primary'], 'missing': ['Secondary']},
      ],
      'errors': <Json>[],
    });
  }

  @override
  Future<Json> ipInfo(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) throw ApiException('Enter an IP or MAC address.');
    final r = _reservations.firstWhere(
        (r) => r['ip'] == q || str(r['mac']).replaceAll(':', '') == q.replaceAll(RegExp(r'[^0-9a-f]'), ''),
        orElse: () => {'ip': q.contains('.') ? q : '192.0.2.77', 'mac': q.contains('.') ? '00:1b:63:10:00:5a' : q, 'name': 'workstation-00'});
    final reserved = _reservations.contains(r);
    return _delay({
      'query': query,
      'results': [
        {
          'ip_address': r['ip'],
          'mac_address': r['mac'],
          'hostname': r['name'],
          'network': '192.0.2.0/24',
          'lease_state': reserved ? 'FREE' : 'LEASED',
          'lease_expires': reserved ? null : DateTime.now().add(const Duration(hours: 6)).toIso8601String(),
          'dhcp_range': reserved ? 'Outside Of DHCP Range' : 'Active DHCP Lease',
          'fixed_address': reserved ? 'Reservation' : null,
          'reserved': reserved,
          'is_conflict': false,
        },
      ],
      'errors': <Json>[],
    });
  }

  @override
  Future<Json> subnetInventory(String network, {String show = 'all'}) {
    final rows = <Json>[];
    for (var i = 1; i < 31; i++) {
      final ip = '192.0.2.$i';
      final res = _reservations.where((r) => r['ip'] == ip).firstOrNull;
      final state = i == 1
          ? 'system'
          : res != null
              ? 'reserved'
              : i % 4 == 0
                  ? 'seen'
                  : i % 9 == 0
                      ? 'dns'
                      : 'free';
      rows.add({
        'ip': ip,
        'state': state,
        'state_label': const {'system': 'Gateway', 'reserved': 'Reserved', 'seen': 'Seen on network', 'dns': 'DNS only', 'free': 'Free'}[state],
        'name': state == 'system' ? 'gateway' : res?['name'] ?? (state == 'dns' ? 'old-host-$i.demo.example' : ''),
        'mac': res?['mac'] ?? (state == 'seen' ? _mac(i) : ''),
        'dns': state == 'dns' ? ['old-host-$i.demo.example'] : <String>[],
        'reserved_on': res == null ? <String>[] : res['servers'],
        'missing_on': res == null ? <String>[] : res['missing'],
      });
    }
    final counts = <String, int>{};
    for (final r in rows) {
      counts[r['state'] as String] = (counts[r['state']] ?? 0) + 1;
    }
    return _delay({
      'network': '192.0.2.0/27',
      'total': rows.length,
      'counts': counts,
      'show': show,
      'results': show == 'all' ? rows : rows.where((r) => r['state'] == (show == 'reserved' ? 'reserved' : show)).toList(),
      'server_errors': <Json>[],
    });
  }

  @override
  Future<Json> pingOptions() => _delay({
        'vrfs': ['default', 'DATA', 'CLINICAL'],
      });

  @override
  Future<List<Json>> deviceSessions() => _delay([
        {
          'id': 'demo',
          'device_name': 'This device',
          'platform': 'ios',
          'app_version': '2.0.0',
          'created_at': DateTime.now().toIso8601String(),
          'last_used_at': DateTime.now().toIso8601String(),
          'current': true,
        },
      ]);

  @override
  Future<void> revokeDeviceSession(String sessionId) async {}

  @override
  Future<Json> registerPush({String? token, required bool enabled}) async => {'push_enabled': false};

  @override
  Future<void> logout() async {}
}

class _DemoChat implements ChatConnection {
  _DemoChat(this.api);

  final DemoApi api;
  final _events = StreamController<Json>.broadcast();
  Timer? _timer;

  @override
  Stream<Json> get events => _events.stream;

  @override
  void send(Json frame) {
    if (frame['type'] == 'cancel') {
      _timer?.cancel();
      _events.add({'type': 'cancelled'});
      return;
    }
    if (frame['type'] == 'steer') {
      _events.add({'type': 'steer_missed', 'id': frame['id'], 'text': frame['text']});
      return;
    }
    final query = str(frame['query']);
    final sessionId = str(frame['chat_session_uuid']);
    final reply = _reply(query);
    final words = reply.split(RegExp(r'(?<= )'));
    var i = 0;
    _events.add({'type': 'tool_start', 'name': 'search_endpoint'});
    _timer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (i == 0) _events.add({'type': 'tool_end', 'name': 'search_endpoint'});
      if (i < words.length) {
        _events.add({'type': 'token', 'text': words[i++]});
        return;
      }
      t.cancel();
      String? newName;
      final session = api._chatSessions.where((s) => s['id'] == sessionId).firstOrNull;
      if (session != null && session['name'] == 'New Session') {
        newName = query.length > 40 ? '${query.substring(0, 40)}…' : query;
        session['name'] = newName;
      }
      api._chatHistory[sessionId]?.add({
        'id': api._seq++,
        'input': query,
        'output': reply,
        'tool_calls_audit': [
          {'tool_name': 'search_endpoint', 'outcome': 'ok'},
        ],
        'interrupted': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      _events.add({'type': 'done', 'session_name': ?newName});
    });
  }

  String _reply(String query) =>
      'This is **demo mode**, so the answer below uses sample data.\n\n'
      'I looked up the endpoint you asked about (`${query.length > 60 ? query.substring(0, 60) : query}`):\n\n'
      '| Field | Value |\n|---|---|\n'
      '| Switch | ${DemoApi.switchName} |\n| Port | Gi1/0/2 |\n| VLAN | 20 |\n| Last seen | 4 minutes ago |\n\n'
      'In the live app the assistant runs NetSmart tools (endpoint search, switch ports, '
      'DHCP, config history) against your network and answers from the results.';

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _events.close();
  }
}
