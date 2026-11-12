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
    final target = kind == 'dhcp_reserve' ? '${body['mac']} ${body['ip'] ?? body['subnet']}' : '$switchName $port';
    _jobStarted[id] = DateTime.now();
    _jobs[id] = {
      'id': id,
      'kind': kind,
      'status': 'queued',
      'done': false,
      'target': target,
      'switch': kind == 'dhcp_reserve' && body['switch_id'] == null ? null : {'id': switchId, 'name': switchName},
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
