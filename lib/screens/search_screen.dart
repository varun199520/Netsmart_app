import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'endpoint_screen.dart';
import 'switch_screen.dart';
import '../widgets/nav_drawer.dart';

enum _Mode { endpoint, switchName }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  _Mode _mode = _Mode.endpoint;
  Timer? _debounce;
  List<Json> _switches = [];
  bool _loadingSwitches = false;
  String? _switchError;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    if (_mode != _Mode.switchName) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _lookupSwitches(value));
  }

  Future<void> _lookupSwitches(String value) async {
    if (value.trim().length < 2) {
      setState(() => _switches = []);
      return;
    }
    setState(() => _loadingSwitches = true);
    try {
      final rows = await context.read<AppState>().api.switches(value.trim());
      if (!mounted || _controller.text != value) return;
      setState(() {
        _switches = rows;
        _switchError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _switchError = e.message);
    } finally {
      if (mounted) setState(() => _loadingSwitches = false);
    }
  }

  void _submit() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    if (_mode == _Mode.endpoint) {
      openEndpoint(context, q);
    } else if (_switches.isNotEmpty) {
      openSwitch(context, _switches.first);
    } else {
      _lookupSwitches(q);
    }
  }

  void _openSaved(Json item) {
    if (item['kind'] == 'switch') {
      openSwitch(context, item);
    } else {
      openEndpoint(context, str(item['value']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final prefs = state.prefs;
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(leading: const NavMenuButton(), title: const Text('Device Tracker')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.endpoint, label: Text('Endpoint'), icon: Icon(Icons.devices_other, size: 18)),
              ButtonSegment(value: _Mode.switchName, label: Text('Switch'), icon: Icon(Icons.lan_outlined, size: 18)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: NS.surface,
              selectedBackgroundColor: NS.accent.withValues(alpha: 0.18),
              selectedForegroundColor: NS.text,
              foregroundColor: NS.textSecondary,
              side: const BorderSide(color: NS.border),
            ),
            onSelectionChanged: (s) {
              setState(() {
                _mode = s.first;
                _switches = [];
              });
              if (_mode == _Mode.switchName) _lookupSwitches(_controller.text);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
            style: NS.mono.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: _mode == _Mode.endpoint ? 'IP, MAC address or hostname' : 'Switch name or management IP',
              prefixIcon: const Icon(Icons.search, color: NS.textSecondary),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == _Mode.endpoint && query.isNotEmpty)
            FilledButton(onPressed: _submit, child: const Text('Search')),
          if (_mode == _Mode.switchName) ..._switchResults(query),
          if (query.isEmpty || _mode == _Mode.endpoint) ...[
            if (prefs.favorites.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SavedList(title: 'Favorites', items: prefs.favorites, onTap: _openSaved),
            ],
            if (prefs.recents.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SavedList(
                title: 'Recent',
                items: prefs.recents,
                onTap: _openSaved,
                trailing: TextButton(
                  onPressed: () async {
                    await prefs.clearRecents();
                    setState(() {});
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
            if (prefs.favorites.isEmpty && prefs.recents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: CenterMessage(
                  icon: Icons.travel_explore,
                  title: 'Find any device',
                  body: 'Search by IP, MAC or hostname to see where it is plugged in, or open a switch to see its ports.',
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _switchResults(String query) {
    if (query.length < 2) return [];
    if (_switchError != null) return [Text(_switchError!, style: const TextStyle(color: NS.danger))];
    if (_loadingSwitches && _switches.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(24), child: Loading())];
    }
    if (_switches.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(16), child: Text('No matching switches.', style: TextStyle(color: NS.textSecondary)))];
    }
    return [
      Card(
        child: Column(children: [
          for (final (i, s) in _switches.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.lan_outlined, color: s['reachable'] == false ? NS.danger : NS.accent),
              title: Text(str(s['name']), style: NS.mono.copyWith(fontSize: 14)),
              subtitle: Text([s['ip'], s['site'], s['role']].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                  style: const TextStyle(color: NS.textSecondary, fontSize: 12.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openSwitch(context, s),
            ),
          ],
        ]),
      ),
    ];
  }
}

class _SavedList extends StatelessWidget {
  const _SavedList({required this.title, required this.items, required this.onTap, this.trailing});

  final String title;
  final List<Json> items;
  final void Function(Json) onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: trailing,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: Icon(item['kind'] == 'switch' ? Icons.lan_outlined : Icons.devices_other, size: 20),
            title: Text(str(item['label'], str(item['value'])), style: NS.mono.copyWith(fontSize: 13.5)),
            subtitle: item['label'] != null && item['label'] != item['value']
                ? Text(str(item['value']), style: const TextStyle(color: NS.textSecondary, fontSize: 12))
                : null,
            onTap: () => onTap(item),
          ),
      ],
    );
  }
}

void openEndpoint(BuildContext context, String query) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EndpointScreen(query: query)));
}

void openSwitch(BuildContext context, Json sw) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SwitchScreen(switchId: str(sw['id']), initialName: str(sw['name'], str(sw['label']))),
  ));
}
