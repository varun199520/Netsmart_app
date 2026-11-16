import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'config.dart';
import 'services/api.dart';
import 'services/auth.dart';
import 'services/demo_api.dart';
import 'services/live_api.dart';
import 'services/prefs.dart';
import 'services/push.dart';
import 'services/web_session.dart';

enum AppStatus { loading, signedOut, offline, updateRequired, ready }

class AppState extends ChangeNotifier {
  AppState(this.prefs) {
    auth.onSessionEnded = _sessionEnded;
  }

  final Prefs prefs;
  final AuthService auth = AuthService();

  AppStatus status = AppStatus.loading;
  NetsmartApi? _api;
  Json? me;
  String? notice;
  bool busy = false;

  NetsmartApi get api => _api!;
  bool get isDemo => _api?.isDemo ?? false;
  Json get caps => jsonMap(me?['capabilities']);
  bool can(String capability) => caps[capability] == true;

  /// The web app's sidebar for this user (see [NetsmartApi.navigation]).
  Json? nav;
  String? navError;
  DateTime? _navLoadedAt;
  bool _navLoading = false;

  /// Loads the sidebar once, then again when it's more than 10 minutes old
  /// (permissions can change on the server) or when [force] is set.
  Future<void> loadNav({bool force = false}) async {
    if (_api == null || _navLoading) return;
    final fresh = _navLoadedAt != null && DateTime.now().difference(_navLoadedAt!) < const Duration(minutes: 10);
    if (nav != null && fresh && !force) return;
    _navLoading = true;
    try {
      nav = await api.navigation();
      navError = null;
      _navLoadedAt = DateTime.now();
    } on ApiException catch (e) {
      navError = e.message;
    } finally {
      _navLoading = false;
      notifyListeners();
    }
  }

  void _clearNav() {
    nav = null;
    navError = null;
    _navLoadedAt = null;
  }

  Future<void> start() async {
    if (await _updateRequired()) {
      _set(AppStatus.updateRequired);
      return;
    }
    if (!await auth.load()) {
      _set(AppStatus.signedOut);
      return;
    }
    _api = LiveApi(auth);
    await reloadMe();
  }

  Future<void> reloadMe() async {
    try {
      me = await api.me();
      _set(AppStatus.ready);
    } on ApiException catch (e) {
      if (e.sessionEnded) return; // _sessionEnded already moved us to signedOut
      notice = e.message;
      _set(e.status == 403 ? AppStatus.signedOut : AppStatus.offline);
    }
  }

  Future<void> signIn() async {
    if (busy) return;
    busy = true;
    notice = null;
    notifyListeners();
    try {
      await auth.signIn();
      _clearNav();
      await clearWebSession();
      _api = LiveApi(auth);
      me = await api.me();
      status = AppStatus.ready;
      if (!prefs.pushAsked) {
        await prefs.setPushAsked();
        await setPush(true);
      }
    } on ApiException catch (e) {
      if (e.code != 'cancelled') notice = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> enterDemo() async {
    _clearNav();
    _api = DemoApi();
    me = await api.me();
    notice = null;
    _set(AppStatus.ready);
  }

  Future<void> signOut() async {
    final api = _api;
    if (api != null) await api.logout();
    _api = null;
    me = null;
    _clearNav();
    await clearWebSession();
    _set(AppStatus.signedOut);
  }

  /// Turns job notifications on or off for this device session.
  Future<bool> setPush(bool enabled) async {
    if (isDemo || _api == null) return false;
    try {
      if (!enabled) {
        await api.registerPush(enabled: false);
        me?['push_enabled'] = false;
      } else {
        final token = await PushService.requestToken();
        if (token == null) return false;
        final res = await api.registerPush(token: token, enabled: true);
        me?['push_enabled'] = res['push_enabled'] == true;
      }
      notifyListeners();
      return me?['push_enabled'] == true;
    } on ApiException {
      return false;
    }
  }

  void _sessionEnded(String message) {
    _api = null;
    me = null;
    _clearNav();
    clearWebSession();
    notice = message;
    _set(AppStatus.signedOut);
  }

  void _set(AppStatus s) {
    status = s;
    notifyListeners();
  }

  Future<bool> _updateRequired() async {
    try {
      final res = await http.get(AppConfig.api('meta')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final minVersion = str(jsonMap(jsonDecode(res.body))['min_app_version']);
      final current = (await PackageInfo.fromPlatform()).version;
      return compareVersions(current, minVersion) < 0;
    } catch (_) {
      return false; // off-network or server down: the real calls will say so
    }
  }
}

int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p.split(RegExp(r'[^0-9]')).first) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
