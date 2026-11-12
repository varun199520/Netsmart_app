/// Where the app talks to. Override at build time, e.g.
/// `flutter run --dart-define=NETSMART_URL=https://netsmart-dev.example.org`.
class AppConfig {
  static const baseUrl = String.fromEnvironment(
    'NETSMART_URL',
    defaultValue: 'https://netsmart-prd.stanfordmed.org',
  );
  static const clientId = 'netsmart-mobile';
  static const callbackScheme = 'org.stanfordmed.netsmart';
  static const redirectUri = '$callbackScheme://auth';
  static const apiPrefix = '/api/mobile/v1';

  static Uri api(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$apiPrefix/$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static Uri chatSocket() {
    final base = Uri.parse(baseUrl);
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/ws/mobile/chat/');
  }
}
