import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dhcp_reserve_screen.dart';
import '../widgets/nav_drawer.dart';

class DhcpScreen extends StatefulWidget {
  const DhcpScreen({super.key});

  @override
  State<DhcpScreen> createState() => _DhcpScreenState();
}

class _DhcpScreenState extends State<DhcpScreen> {
  final _controller = TextEditingController();
  Json? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<AppState>().api.dhcpSearch(q);
      if (mounted) setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final rows = jsonList(result?['results']);
    final errors = (result?['errors'] as List? ?? []).map((e) => '$e').toList();
    return Scaffold(
      appBar: AppBar(leading: const NavMenuButton(), title: const Text('DHCP Reservations')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New reservation'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DhcpReserveScreen())),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            style: NS.mono.copyWith(fontSize: 15),
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'MAC or IP address',
              prefixIcon: const Icon(Icons.search, color: NS.textSecondary),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(_controller.clear)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loading || _controller.text.trim().isEmpty ? null : _search, child: const Text('Search')),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Loading())
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: NS.danger))
          else if (result == null)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: CenterMessage(
                icon: Icons.dns_outlined,
                title: 'Find a reservation',
                body: 'Search every DHCP server by MAC or IP address.',
              ),
            )
          else ...[
            for (final e in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber, size: 16, color: NS.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Couldn't search $e — results may be incomplete.",
                        style: const TextStyle(color: NS.warning, fontSize: 13)),
                  ),
                ]),
              ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No reservation found for ${result['query']}.',
                    style: const TextStyle(color: NS.textSecondary)),
              ),
            for (final r in rows) ...[
              _ReservationCard(row: r),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.row});

  final Json row;

  @override
  Widget build(BuildContext context) {
    final servers = (row['servers'] as List? ?? []).map((s) => '$s').toList();
    final missing = (row['missing'] as List? ?? []).map((s) => '$s').toList();
    return SectionCard(
      title: str(row['name'], 'Reservation'),
      trailing: missing.isEmpty
          ? const Pill('in sync', color: NS.success)
          : Pill('missing on ${missing.length}', color: NS.warning),
      children: [
        KV('IP', str(row['ip']), mono: true),
        KV('MAC', str(row['mac']), mono: true),
        KV('Network', str(row['network']), mono: true),
        if (str(row['comment']).isNotEmpty) KV('Comment', str(row['comment'])),
        KV('On servers', servers.join(', ')),
        if (missing.isNotEmpty) KV('Missing on', missing.join(', '), valueColor: NS.warning),
      ],
    );
  }
}
