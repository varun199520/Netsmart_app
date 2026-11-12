import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.children, this.padding});

  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(title!.toUpperCase(),
                        style: const TextStyle(
                            color: NS.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ),
                  ?trailing,
                ]),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Label/value row; long-press copies the value.
class KV extends StatelessWidget {
  const KV(this.label, this.value, {super.key, this.mono = false, this.valueColor});

  final String label;
  final String? value;
  final bool mono;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final v = (value == null || value!.isEmpty) ? '—' : value!;
    return InkWell(
      onLongPress: value == null || value!.isEmpty ? null : () => copyText(context, v),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(label, style: const TextStyle(color: NS.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(v,
                style: (mono ? NS.mono : const TextStyle())
                    .copyWith(fontSize: 13.5, color: valueColor ?? (v == '—' ? NS.textDim : NS.text))),
          ),
        ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = NS.textSecondary, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

Color freshnessColor(String? state) => switch (state) {
      'fresh' || 'live' || 'current' => NS.success,
      'recent' || 'aging' => NS.warning,
      'stale' || 'old' => NS.orange,
      _ => NS.textSecondary,
    };

Color portStatusColor(String? status) => switch (status) {
      'free' => NS.success,
      'recent' => NS.warning,
      'in_use' => NS.accent,
      'uplink' => NS.purple,
      _ => NS.textSecondary,
    };

String portStatusLabel(String? status) => switch (status) {
      'free' => 'Free',
      'recent' => 'Recently used',
      'in_use' => 'In use',
      'uplink' => 'Uplink',
      _ => 'Unknown',
    };

class CenterMessage extends StatelessWidget {
  const CenterMessage({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: NS.textDim),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: NS.textSecondary)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => CenterMessage(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        body: message,
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: NS.purple.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: const Text('Demo mode — sample data, nothing is changed on a real network',
          textAlign: TextAlign.center, style: TextStyle(color: NS.purple, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

void copyText(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  showSnack(context, 'Copied $text');
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFF3D1518) : null,
    ));
}

Future<bool> confirm(BuildContext context,
    {required String title, required String body, String action = 'Continue', bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: Text(body, style: const TextStyle(color: NS.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDA3633)) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

DateTime? parseTime(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String ago(dynamic v) {
  final t = parseTime(v);
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  return DateFormat.yMMMd().format(t);
}

String stamp(dynamic v) {
  final t = parseTime(v);
  return t == null ? '—' : DateFormat('MMM d, HH:mm').format(t);
}
