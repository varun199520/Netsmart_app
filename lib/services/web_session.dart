import 'package:webview_flutter/webview_flutter.dart';

/// Forgets the NetSmart web sign-in held by the in-app web views (cookies),
/// so a sign-out in the app also signs the web pages out on this device.
Future<void> clearWebSession() async {
  // No platform implementation in widget tests / unsupported platforms.
  if (WebViewPlatform.instance == null) return;
  try {
    await WebViewCookieManager().clearCookies();
  } on Object {
    // Best effort: the server-side session is ended separately.
  }
}
