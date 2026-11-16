import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// One way of searching in a [ToolSearchScreen] (e.g. "by VLAN" / "by switch").
class SearchMode {
  const SearchMode(this.key, this.label, this.hint, {this.keyboard = TextInputType.text});

  final String key;
  final String label;
  final String hint;
  final TextInputType keyboard;
}

/// Search box + results, the shape most NetSmart lookup pages share.
class ToolSearchScreen extends StatefulWidget {
  const ToolSearchScreen({
    super.key,
    required this.title,
    required this.modes,
    required this.search,
    required this.results,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyBody,
    this.initialQuery,
  });

  final String title;
  final List<SearchMode> modes;
  final Future<Json> Function(String mode, String query) search;
  final List<Widget> Function(BuildContext context, Json result) results;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyBody;
  final String? initialQuery;

  @override
  State<ToolSearchScreen> createState() => _ToolSearchScreenState();
}

class _ToolSearchScreenState extends State<ToolSearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late String _mode = widget.modes.first.key;
  Json? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SearchMode get _current => widget.modes.firstWhere((m) => m.key == _mode);

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.search(_mode, q);
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (widget.modes.length > 1) ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: NS.accent.withValues(alpha: 0.18),
                selectedForegroundColor: NS.text,
                foregroundColor: NS.textSecondary,
                side: const BorderSide(color: NS.border),
              ),
              segments: [for (final m in widget.modes) ButtonSegment(value: m.key, label: Text(m.label))],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _result = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: _current.keyboard,
            textInputAction: TextInputAction.search,
            style: NS.mono.copyWith(fontSize: 15),
            onSubmitted: (_) => _run(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _current.hint,
              prefixIcon: const Icon(Icons.search, color: NS.textSecondary),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(_controller.clear)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loading || _controller.text.trim().isEmpty ? null : _run, child: const Text('Search')),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Loading())
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: NS.danger))
          else if (result == null)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: CenterMessage(icon: widget.emptyIcon, title: widget.emptyTitle, body: widget.emptyBody),
            )
          else
            ...widget.results(context, result),
        ],
      ),
    );
  }
}

/// "Couldn't reach X" lines for partial results from several servers.
List<Widget> serverErrors(dynamic errors) => [
      for (final e in jsonList(errors))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber, size: 16, color: NS.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text("Couldn't query ${str(e['server'], 'a server')} — results may be incomplete.",
                  style: const TextStyle(color: NS.warning, fontSize: 13)),
            ),
          ]),
        ),
    ];

/// Plain "nothing found" line under a search.
Widget noResults(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: const TextStyle(color: NS.textSecondary)),
    );

/// Generic future-backed screen body: loading / error+retry / content, with pull-to-refresh.
class AsyncBody<T> extends StatefulWidget {
  const AsyncBody({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncBody<T>> createState() => _AsyncBodyState<T>();
}

class _AsyncBodyState<T> extends State<AsyncBody<T>> {
  T? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return _error != null ? ErrorView(_error!, onRetry: _reload) : const Loading();
    }
    return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, data, _reload));
  }
}
