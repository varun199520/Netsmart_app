import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_state.dart';
import '../config.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A NetSmart web page inside the app, already signed in.
///
/// The app asks the server for a one-time ticket (bound to this device's
/// mobile session), POSTs it to `/mobile/auth/web/` inside the web view, and
/// the server answers with the normal web session cookie and a redirect to
/// [path] — so the user never signs in twice. The web sidebar/top bar are
/// hidden because the app's own drawer and app bar replace them.
class WebToolScreen extends StatefulWidget {
  const WebToolScreen({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  State<WebToolScreen> createState() => _WebToolScreenState();
}

const _chromeCss = '.rb-sidebar,.rb-overlay,.rb-topbar{display:none!important}'
    '.rb-shell{margin-left:0!important;height:100vh!important}'
    'html,body{-webkit-text-size-adjust:100%;background:#0d1117}';

const _injectChrome = '''
(function(){
  if (document.getElementById('ns-app-chrome')) return;
  var s = document.createElement('style');
  s.id = 'ns-app-chrome';
  s.textContent = "$_chromeCss";
  (document.head || document.documentElement).appendChild(s);
})();
''';

class _WebToolScreenState extends State<WebToolScreen> {
  late final WebViewController _web;
  final _host = Uri.parse(AppConfig.baseUrl).host;
  double _progress = 0;
  String? _error;
  bool _signingIn = true;
  bool _retried = false;
  String? _pageTitle;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(NS.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p / 100);
        },
        onPageStarted: (_) => _web.runJavaScript(_injectChrome).catchError((_) {}),
        onPageFinished: _pageFinished,
        onNavigationRequest: _navigationRequest,
        onWebResourceError: (e) {
          if (e.isForMainFrame == false || !mounted) return;
          setState(() => _error = e.description.isEmpty ? 'The page could not be loaded.' : e.description);
        },
      ));
    _signIn();
  }

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      final s = await context.read<AppState>().api.webSession(widget.path);
      final body = 'ticket=${Uri.encodeQueryComponent(str(s['ticket']))}';
      await _web.loadRequest(
        Uri.parse(str(s['url'])),
        method: LoadRequestMethod.post,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: Uint8List.fromList(utf8.encode(body)),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _pageFinished(String url) async {
    await _web.runJavaScript(_injectChrome).catchError((_) {});
    final uri = Uri.tryParse(url);
    // Landed on a login page: the web session didn't stick (or expired while
    // the page was open). Hand the session over again, once.
    if (uri != null && _isLoginPage(uri)) {
      if (!_retried) {
        _retried = true;
        await _signIn();
      } else if (mounted) {
        setState(() => _error = 'NetSmart asked to sign in again. Close this page and try once more.');
      }
      return;
    }
    final title = await _web.getTitle();
    final back = await _web.canGoBack();
    if (!mounted) return;
    setState(() {
      _pageTitle = (title == null || title.trim().isEmpty) ? null : title.replaceAll(RegExp(r'\s*[|–-]\s*NetSmart\s*$'), '');
      _canGoBack = back;
    });
  }

  bool _isLoginPage(Uri uri) =>
      uri.host == _host &&
      (uri.path.startsWith('/accounts/login') || uri.path.startsWith('/oauth2/login') || uri.path == '/login/');

  NavigationDecision _navigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    final sameSite = uri.host == _host || uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob';
    // The company SSO login lives on another host; let it load inside the
    // view so a rare re-login still lands back here.
    final sso = uri.host.contains('adfs') || uri.host.contains('login.microsoftonline');
    if (sameSite || sso) return NavigationDecision.navigate;
    if (request.isMainFrame) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _web.goBack();
        final back = await _web.canGoBack();
        if (mounted) setState(() => _canGoBack = back);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle ?? widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: _error != null ? _signIn : () => _web.reload(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: (_signingIn || (_progress > 0 && _progress < 1)) && _error == null
                ? LinearProgressIndicator(
                    value: _signingIn ? null : _progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  )
                : const SizedBox(height: 2),
          ),
        ),
        body: _error != null
            ? ErrorView(_error!, onRetry: () {
                _retried = false;
                _signIn();
              })
            : WebViewWidget(controller: _web),
      ),
    );
  }
}
