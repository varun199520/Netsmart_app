import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../config.dart';
import 'api.dart';
import 'auth.dart';

class LiveApi implements NetsmartApi {
  LiveApi(this.auth, {http.Client? client}) : _http = client ?? http.Client();

  final AuthService auth;
  final http.Client _http;

  @override
  bool get isDemo => false;

  Future<dynamic> _call(String method, String path, {Map<String, String>? query, Json? body}) async {
    var res = await _send(method, path, query, body, await auth.accessToken());
    if (res.statusCode == 401) {
      res = await _send(method, path, query, body, await auth.accessToken(forceRefresh: true));
      if (res.statusCode == 401) {
        await auth.signOutLocally();
        auth.onSessionEnded?.call('Your session ended. Sign in again.');
        throw ApiException('Your session ended. Sign in again.', status: 401, code: 'session_ended');
      }
    }
    dynamic decoded;
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body);
      } on FormatException {
        decoded = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    final detail = decoded is Map ? decoded['detail'] : null;
    throw ApiException(
      detail != null ? str(detail) : _fallbackMessage(res.statusCode),
      status: res.statusCode,
      code: res.statusCode == 403 ? 'forbidden' : 'http_${res.statusCode}',
    );
  }

  Future<http.Response> _send(String method, String path, Map<String, String>? query, Json? body, String token) async {
    final request = http.Request(method, AppConfig.api(path, query))
      ..headers.addAll({'Authorization': 'Bearer $token', 'Accept': 'application/json'});
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(request).timeout(const Duration(seconds: 30));
      return await http.Response.fromStream(streamed).timeout(const Duration(seconds: 30));
    } on SocketException {
      throw ApiException(offlineMessage, code: 'offline');
    } on TimeoutException {
      throw ApiException('NetSmart took too long to answer. Try again.', code: 'timeout');
    } on HandshakeException {
      throw ApiException('Secure connection to NetSmart failed.', code: 'tls');
    } on http.ClientException {
      throw ApiException(offlineMessage, code: 'offline');
    }
  }

  static String _fallbackMessage(int status) => switch (status) {
        403 => "You don't have access to this.",
        404 => 'Not found.',
        429 => 'Too many requests. Wait a moment and try again.',
        >= 500 => 'NetSmart had a problem ($status). Try again shortly.',
        _ => 'Request failed ($status).',
      };

  Future<Json> _get(String path, [Map<String, String>? query]) async => jsonMap(await _call('GET', path, query: query));
  Future<Json> _post(String path, [Json? body]) async => jsonMap(await _call('POST', path, body: body ?? {}));

  @override
  Future<Json> me() => _get('me');

  @override
  Future<Json> search(String query) => _get('search', {'q': query});

  @override
  Future<List<Json>> switches(String query) async => jsonList((await _get('switches', {'q': query}))['results']);

  @override
  Future<Json> switchDetail(String switchId) => _get('switches/$switchId');

  @override
  Future<Json> switchEndpoints(String switchId,
          {int page = 1, int pageSize = 50, String sort = 'last_seen', String filter = ''}) =>
      _get('switches/$switchId/endpoints',
          {'page': '$page', 'page_size': '$pageSize', 'sort': sort, if (filter.isNotEmpty) 'filter': filter});

  @override
  Future<Json> switchPorts(String switchId) => _get('switches/$switchId/ports');

  @override
  Future<List<Json>> switchVlans(String switchId) async =>
      jsonList((await _get('switches/$switchId/vlans'))['results']);

  @override
  Future<Json> refreshSwitch(String switchId) => _post('switches/$switchId/refresh');

  @override
  Future<Json> refreshStatus(String switchId, String jobId) => _get('switches/$switchId/refresh/$jobId');

  @override
  Future<Json> submitJob(Json body) => _post('jobs', body);

  @override
  Future<Json> job(String jobId) => _get('jobs/$jobId');

  @override
  Future<List<Json>> jobs() async => jsonList((await _get('jobs'))['results']);

  @override
  Future<Json> dhcpSearch(String query) => _get('dhcp/reservations', {'q': query});

  @override
  Future<List<Json>> dhcpSubnets(String switchId) async =>
      jsonList((await _get('dhcp/switches/$switchId/subnets'))['results']);

  @override
  Future<List<Json>> chatSessions() async => jsonList((await _get('chat/sessions'))['results']);

  @override
  Future<Json> createChatSession() => _post('chat/sessions');

  @override
  Future<void> deleteChatSession(String sessionId) => _call('DELETE', 'chat/sessions/$sessionId');

  @override
  Future<Json> chatHistory(String sessionId) => _get('chat/sessions/$sessionId/history');

  @override
  Future<List<Json>> chatModels() async => jsonList((await _get('chat/models'))['results']);

  @override
  Future<ChatConnection> openChat() async {
    var conn = await _LiveChatConnection.connect(await auth.accessToken());
    if (conn.rejectedCode == 'token_expired' || conn.rejectedCode == 'token_invalid') {
      await conn.close();
      conn = await _LiveChatConnection.connect(await auth.accessToken(forceRefresh: true));
    }
    if (conn.rejectedCode != null) {
      final message = conn.rejectedText ?? 'Chat connection was refused.';
      await conn.close();
      throw ApiException(message, code: conn.rejectedCode);
    }
    return conn;
  }

  @override
  Future<Json> navigation() => _get('nav');

  @override
  Future<Json> webSession(String path) => _post('auth/web-session', {'path': path});

  @override
  Future<Json> dcVlans(Map<String, String> filters) => _get('tools/dc-vlans', filters);

  @override
  Future<Json> changeRequests({bool refresh = false}) => _get('tools/changes', {if (refresh) 'refresh': '1'});

  @override
  Future<Json> changeRequest(String sysId) => _get('tools/changes/${Uri.encodeComponent(sysId)}');

  @override
  Future<List<Json>> calendarEvents(DateTime from, DateTime to) async =>
      jsonList((await _get('tools/calendar', {'from': _day(from), 'to': _day(to)}))['results']);

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Json> nurseCallSwitches() => _get('tools/nurse-call');

  @override
  Future<List<Json>> sites(String query) async =>
      jsonList((await _get('tools/sites', {if (query.isNotEmpty) 'q': query}))['results']);

  @override
  Future<Json> site(String siteId) => _get('tools/sites/${Uri.encodeComponent(siteId)}');

  @override
  Future<Json> dnsLookup(String query) => _get('tools/dns', {'q': query});

  @override
  Future<Json> ipInfo(String query) => _get('tools/ip-info', {'q': query});

  @override
  Future<Json> subnetInventory(String network, {String show = 'all'}) =>
      _get('tools/subnet', {'net': network, 'show': show});

  @override
  Future<Json> pingOptions() => _get('tools/ping');

  @override
  Future<List<Json>> deviceSessions() async => jsonList((await _get('auth/sessions'))['results']);

  @override
  Future<void> revokeDeviceSession(String sessionId) => _call('DELETE', 'auth/sessions/$sessionId');

  @override
  Future<Json> registerPush({String? token, required bool enabled}) =>
      _post('push/register', {'enabled': enabled, 'token': ?token});

  @override
  Future<void> logout() async {
    try {
      await _post('auth/logout');
    } on ApiException {
      // Signing out locally is what matters; the server session expires on its own.
    }
    await auth.signOutLocally();
  }
}

class _LiveChatConnection implements ChatConnection {
  _LiveChatConnection(this._channel);

  final IOWebSocketChannel _channel;
  final _events = StreamController<Json>.broadcast();
  String? rejectedCode;
  String? rejectedText;

  /// Connects and waits briefly for an immediate `auth_error` frame, which the
  /// server sends (then closes) when the token or network is refused.
  static Future<_LiveChatConnection> connect(String token) async {
    final channel = IOWebSocketChannel.connect(
      AppConfig.chatSocket(),
      headers: {'Authorization': 'Bearer $token'},
      pingInterval: const Duration(seconds: 25),
      connectTimeout: const Duration(seconds: 15),
    );
    try {
      await channel.ready;
    } on Object {
      throw ApiException(offlineMessage, code: 'offline');
    }
    final conn = _LiveChatConnection(channel);
    final firstAuth = Completer<void>();
    channel.stream.listen(
      (raw) {
        final frame = raw is String ? _decode(raw) : null;
        if (frame == null) return;
        if (frame['type'] == 'auth_error' && !firstAuth.isCompleted) {
          conn.rejectedCode = str(frame['code']);
          conn.rejectedText = str(frame['text']);
          firstAuth.complete();
        }
        if (!conn._events.isClosed) conn._events.add(frame);
      },
      onDone: () {
        if (!firstAuth.isCompleted) firstAuth.complete();
        if (!conn._events.isClosed) conn._events.add({'type': 'closed', 'code': channel.closeCode});
      },
      onError: (_) {
        if (!firstAuth.isCompleted) firstAuth.complete();
      },
      cancelOnError: false,
    );
    await firstAuth.future.timeout(const Duration(milliseconds: 600), onTimeout: () {});
    return conn;
  }

  static Json? _decode(String raw) {
    try {
      return jsonMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Stream<Json> get events => _events.stream;

  @override
  void send(Json frame) => _channel.sink.add(jsonEncode(frame));

  @override
  Future<void> close() async {
    await _channel.sink.close();
    await _events.close();
  }
}
