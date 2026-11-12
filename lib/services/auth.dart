import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import 'api.dart';

const offlineMessage = "Can't reach NetSmart. Connect to the Stanford network or VPN and try again.";

/// Sign-in (system browser + PKCE) and the token pair, kept in the Keychain.
/// Tokens never leave this device class; the device id binds the refresh token.
class AuthService {
  AuthService({http.Client? client}) : _http = client ?? http.Client();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _kAccess = 'access_token';
  static const _kAccessExp = 'access_expires_at';
  static const _kRefresh = 'refresh_token';
  static const _kDevice = 'device_id';

  final http.Client _http;
  String? _access;
  DateTime? _accessExp;
  String? _refresh;
  Future<void>? _refreshing;

  /// Called once when the server ends the session (revoked, expired, access removed).
  void Function(String message)? onSessionEnded;

  bool get hasSession => _refresh != null;

  Future<bool> load() async {
    try {
      _access = await _storage.read(key: _kAccess);
      _refresh = await _storage.read(key: _kRefresh);
      final exp = await _storage.read(key: _kAccessExp);
      _accessExp = exp == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(exp));
    } on PlatformException {
      await _wipeTokens();
    }
    return hasSession;
  }

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _kDevice);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _randomUrlSafe(24);
    await _storage.write(key: _kDevice, value: id);
    return id;
  }

  /// Opens NetSmart's sign-in page in the system browser and exchanges the
  /// one-time code for tokens. Returns the signed-in user.
  Future<Json> signIn() async {
    final verifier = _randomUrlSafe(48);
    final challenge = _b64(sha256.convert(ascii.encode(verifier)).bytes);
    final state = _randomUrlSafe(16);
    final authorize = Uri.parse('${AppConfig.baseUrl}/mobile/auth/authorize/').replace(queryParameters: {
      'response_type': 'code',
      'client_id': AppConfig.clientId,
      'redirect_uri': AppConfig.redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });

    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: authorize.toString(),
        callbackUrlScheme: AppConfig.callbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw ApiException('Sign-in was cancelled.', code: 'cancelled');
      throw ApiException('Sign-in failed: ${e.message ?? e.code}');
    }

    final params = Uri.parse(callback).queryParameters;
    if (params['state'] != state) throw ApiException('Sign-in response did not match. Try again.');
    if (params['error'] == 'access_denied') {
      throw ApiException(
        'Your account is not enabled for the NetSmart app. Ask the network team for mobile app access.',
        code: 'access_denied',
      );
    }
    final code = params['code'];
    if (code == null) throw ApiException('Sign-in did not return a code. Try again.');

    final body = await _tokenRequest({
      'grant_type': 'authorization_code',
      'client_id': AppConfig.clientId,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': AppConfig.redirectUri,
      ...await _deviceFields(),
    });
    await _store(body);
    return jsonMap(body['user']);
  }

  /// A valid access token, refreshing first if it is about to expire.
  Future<String> accessToken({bool forceRefresh = false}) async {
    if (_refresh == null) throw ApiException('Signed out.', code: 'session_ended');
    final fresh = _access != null &&
        _accessExp != null &&
        _accessExp!.isAfter(DateTime.now().add(const Duration(seconds: 30)));
    if (forceRefresh || !fresh) await refresh();
    return _access!;
  }

  /// Rotates the token pair. Concurrent callers share one in-flight refresh,
  /// so a burst of 401s never spends the same refresh token twice.
  Future<void> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<void> _doRefresh() async {
    final refreshToken = _refresh;
    if (refreshToken == null) throw ApiException('Signed out.', code: 'session_ended');
    final Json body;
    try {
      body = await _tokenRequest({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'device_id': await deviceId(),
      });
    } on ApiException catch (e) {
      if (e.code == 'invalid_grant' || e.code == 'access_denied') {
        await _wipeTokens();
        onSessionEnded?.call(e.message);
        throw ApiException(e.message, status: e.status, code: 'session_ended');
      }
      rethrow;
    }
    await _store(body);
  }

  Future<void> signOutLocally() => _wipeTokens();

  Future<Json> _tokenRequest(Map<String, String> fields) async {
    final http.Response res;
    try {
      res = await _http
          .post(AppConfig.api('auth/token'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode(fields))
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException(offlineMessage, code: 'offline');
    } on TimeoutException {
      throw ApiException(offlineMessage, code: 'offline');
    } on HandshakeException {
      throw ApiException('Secure connection to NetSmart failed.', code: 'tls');
    }
    final Json body;
    try {
      body = jsonMap(jsonDecode(res.body));
    } on FormatException {
      throw ApiException('NetSmart returned an unexpected response (${res.statusCode}).', status: res.statusCode);
    }
    if (res.statusCode != 200) {
      throw ApiException(
        str(body['error_description'] ?? body['detail'], 'Sign-in failed (${res.statusCode}).'),
        status: res.statusCode,
        code: str(body['error'], 'http_${res.statusCode}'),
      );
    }
    return body;
  }

  Future<void> _store(Json body) async {
    _access = str(body['access_token']);
    _refresh = str(body['refresh_token']);
    final expiresIn = body['expires_in'] is int ? body['expires_in'] as int : 900;
    _accessExp = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.write(key: _kAccess, value: _access);
    await _storage.write(key: _kRefresh, value: _refresh);
    await _storage.write(key: _kAccessExp, value: _accessExp!.millisecondsSinceEpoch.toString());
  }

  Future<void> _wipeTokens() async {
    _access = null;
    _refresh = null;
    _accessExp = null;
    for (final key in [_kAccess, _kRefresh, _kAccessExp]) {
      try {
        await _storage.delete(key: key);
      } on PlatformException {
        // Keychain unavailable; in-memory state is already cleared.
      }
    }
  }

  Future<Map<String, String>> _deviceFields() async {
    var name = 'Unknown device';
    var platform = 'other';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        name = '${ios.name} (${ios.utsname.machine})';
        platform = 'ios';
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        name = '${android.manufacturer} ${android.model}';
        platform = 'android';
      }
    } catch (_) {
      // Device name is cosmetic; keep the defaults.
    }
    final pkg = await PackageInfo.fromPlatform();
    return {
      'device_id': await deviceId(),
      'device_name': name,
      'platform': platform,
      'app_version': pkg.version,
    };
  }

  static String _randomUrlSafe(int bytes) {
    final rnd = Random.secure();
    return _b64(List<int>.generate(bytes, (_) => rnd.nextInt(256)));
  }

  static String _b64(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');
}
