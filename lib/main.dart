import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'services/prefs.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final state = AppState(await Prefs.load());
  runApp(ChangeNotifierProvider.value(value: state, child: const NetSmartApp()));
  state.start();
}

class NetSmartApp extends StatelessWidget {
  const NetSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetSmart',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      builder: (context, child) => _DemoFrame(child: child!),
      home: const _Root(),
    );
  }
}

/// Keeps the demo banner above every route while demo mode is on.
class _DemoFrame extends StatelessWidget {
  const _DemoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final demo = context.select<AppState, bool>((s) => s.status == AppStatus.ready && s.isDemo);
    if (!demo) return child;
    return ColoredBox(
      color: NS.bg,
      child: Column(children: [
        const SafeArea(bottom: false, child: Material(type: MaterialType.transparency, child: DemoBanner())),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
      ]),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return switch (state.status) {
      AppStatus.loading => const Scaffold(body: Loading()),
      AppStatus.signedOut => const SignInScreen(),
      AppStatus.ready => HomeShell(key: ValueKey(state.isDemo)),
      AppStatus.updateRequired => const Scaffold(
          body: CenterMessage(
            icon: Icons.system_update,
            title: 'Update required',
            body: 'This version of NetSmart is no longer supported. Update the app from the App Store.',
          ),
        ),
      AppStatus.offline => Scaffold(
          body: CenterMessage(
            icon: Icons.wifi_off,
            title: "Can't reach NetSmart",
            body: state.notice ?? 'Connect to the Stanford network or VPN and try again.',
            action: Column(children: [
              FilledButton(onPressed: state.reloadMe, child: const Text('Try again')),
              const SizedBox(height: 8),
              TextButton(onPressed: state.signOut, child: const Text('Sign out')),
            ]),
          ),
        ),
    };
  }
}
