import 'dart:async';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  /// The server ended the session (revoked, expired, access removed).
  bool get sessionEnded => code == 'session_ended';

  @override
  String toString() => message;
}

/// Everything the screens need from NetSmart. Implemented by [LiveApi] and,
/// for App Review / demos, by the offline [DemoApi].
abstract class NetsmartApi {
  bool get isDemo;

  Future<Json> me();

  Future<Json> search(String query);
  Future<List<Json>> switches(String query);
  Future<Json> switchDetail(String switchId);
  Future<Json> switchEndpoints(String switchId, {int page = 1, int pageSize = 50, String sort = 'last_seen', String filter = ''});
  Future<Json> switchPorts(String switchId);
  Future<List<Json>> switchVlans(String switchId);
  Future<Json> refreshSwitch(String switchId);
  Future<Json> refreshStatus(String switchId, String jobId);

  Future<Json> submitJob(Json body);
  Future<Json> job(String jobId);
  Future<List<Json>> jobs();

  Future<Json> dhcpSearch(String query);
  Future<List<Json>> dhcpSubnets(String switchId);

  Future<List<Json>> chatSessions();
  Future<Json> createChatSession();
  Future<void> deleteChatSession(String sessionId);
  Future<Json> chatHistory(String sessionId);
  Future<List<Json>> chatModels();
  Future<ChatConnection> openChat();

  /// The web app's sidebar for this user (same sections, groups, links and
  /// permission filtering as the NetSmart web UI).
  /// `{sections: [{title, accent, groups: [{label, icon, items: [{title, path|url, native?, external?}]}]}]}`
  Future<Json> navigation();

  /// One-time ticket that signs the in-app web view into the NetSmart web UI
  /// as the current user (`{url, ticket, expires_in}`); the web view POSTs
  /// `ticket` to `url` and the server redirects to [path].
  Future<Json> webSession(String path);

  // Native versions of web tools (`/api/mobile/v1/tools/...`).
  Future<Json> dcVlans(Map<String, String> filters);
  Future<Json> changeRequests({bool refresh = false});
  Future<Json> changeRequest(String sysId);
  Future<List<Json>> calendarEvents(DateTime from, DateTime to);
  Future<Json> nurseCallSwitches();
  Future<List<Json>> sites(String query);
  Future<Json> site(String siteId);
  Future<Json> dnsLookup(String query);
  Future<Json> ipInfo(String query);
  Future<Json> subnetInventory(String network, {String show = 'all'});
  Future<Json> pingOptions();

  Future<List<Json>> deviceSessions();
  Future<void> revokeDeviceSession(String sessionId);
  Future<Json> registerPush({String? token, required bool enabled});
  Future<void> logout();
}

/// One chat WebSocket. [events] carries the server's JSON frames
/// (token / tool_start / tool_end / error / done / cancelled / steer_* / auth_error);
/// a synthetic `{"type": "closed"}` frame is emitted when the socket drops.
abstract class ChatConnection {
  Stream<Json> get events;
  void send(Json frame);
  Future<void> close();
}

String str(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

List<Json> jsonList(dynamic v) => v is List ? v.whereType<Map>().map((e) => Json.from(e)).toList() : <Json>[];

Json jsonMap(dynamic v) => v is Map ? Json.from(v) : <String, dynamic>{};
