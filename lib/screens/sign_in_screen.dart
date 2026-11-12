import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset('assets/logo.png', width: 96, height: 96),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('NetSmart',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Find devices, manage switch ports and DHCP, and ask the network assistant.',
                    textAlign: TextAlign.center, style: TextStyle(color: NS.textSecondary, fontSize: 15)),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: state.busy ? null : state.signIn,
                  icon: state.busy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: const Text('Sign in with your Stanford account'),
                ),
                if (state.notice != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NS.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NS.danger.withValues(alpha: 0.4)),
                    ),
                    child: Text(state.notice!, style: const TextStyle(color: NS.text, fontSize: 13.5)),
                  ),
                ],
                const SizedBox(height: 14),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline, size: 14, color: NS.textSecondary),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text('Requires the Stanford network or VPN',
                        style: TextStyle(color: NS.textSecondary, fontSize: 12.5)),
                  ),
                ]),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.busy ? null : state.enterDemo,
                  child: const Text('Explore a demo with sample data'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
