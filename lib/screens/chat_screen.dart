import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _SteerState { queued, delivered, notDelivered }

class _Tool {
  _Tool(this.name, this.callId);

  final String name;
  final String? callId;
  bool running = true;
  bool failed = false;
}

class _Msg {
  _Msg.user(this.text, {this.steerId}) : fromUser = true;
  _Msg.assistant([this.text = '']) : fromUser = false;

  final bool fromUser;
  String text;
  final tools = <_Tool>[];
  String? error;
  bool interrupted = false;
  bool streaming = false;
  int? steerId;
  _SteerState? steer;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.sessionId, required this.initialName});

  final String sessionId;
  final String initialName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  final _pendingSteers = <int, _Msg>{};
  late String _title = widget.initialName;

  List<Json> _models = [];
  String? _model;
  String _mode = 'general';
  bool _loading = true;
  String? _loadError;

  ChatConnection? _conn;
  StreamSubscription<Json>? _sub;
  Future<ChatConnection?>? _connecting;
  _Msg? _current;
  int _steerSeq = 0;

  bool get _streaming => _current != null;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _conn?.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([state.api.chatHistory(widget.sessionId), state.api.chatModels()]);
      if (!mounted) return;
      final history = results[0] as Json;
      final models = results[1] as List<Json>;
      final saved = state.prefs.chatModel;
      setState(() {
        _title = str(history['name'], _title);
        _models = models;
        _model = models.any((m) => m['id'] == saved) ? saved : (models.isEmpty ? null : str(models.first['id']));
        _messages.clear();
        for (final row in jsonList(history['results'])) {
          _messages.add(_Msg.user(str(row['input'])));
          final reply = _Msg.assistant(str(row['output']))..interrupted = row['interrupted'] == true;
          for (final t in jsonList(row['tool_calls_audit'])) {
            reply.tools.add(_Tool(str(t['tool_name'], 'tool'), null)
              ..running = false
              ..failed = str(t['outcome'], 'ok') != 'ok');
          }
          _messages.add(reply);
        }
        _loading = false;
      });
      _jumpToEnd();
      _ensureConnection();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.message;
        });
      }
    }
  }

  Future<ChatConnection?> _ensureConnection() {
    if (_conn != null) return Future.value(_conn);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<ChatConnection?> _connect() async {
    try {
      final conn = await context.read<AppState>().api.openChat();
      if (!mounted) {
        await conn.close();
        return null;
      }
      _conn = conn;
      _sub = conn.events.listen(_onEvent);
      return conn;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      return null;
    }
  }

  void _onEvent(Json frame) {
    if (!mounted) return;
    final msg = _current;
    switch (str(frame['type'])) {
      case 'token':
        if (msg == null) return;
        setState(() => msg.text += str(frame['text']));
        _followEnd();
      case 'tool_start':
        if (msg == null) return;
        setState(() => msg.tools.add(_Tool(str(frame['name'], 'tool'), frame['call_id']?.toString())));
        _followEnd();
      case 'tool_end':
        if (msg == null) return;
        final callId = frame['call_id']?.toString();
        final name = str(frame['name']);
        final tool = msg.tools.where((t) => t.running && (callId != null ? t.callId == callId : t.name == name)).firstOrNull ??
            msg.tools.where((t) => t.running && t.name == name).firstOrNull;
        setState(() {
          if (tool == null) {
            msg.tools.add(_Tool(name, callId)..running = false);
          } else {
            tool.running = false;
            tool.failed = str(frame['outcome'], 'ok') != 'ok';
          }
        });
      case 'error':
        final text = str(frame['text'], 'Something went wrong.');
        if (msg != null) {
          setState(() => msg.error = text);
        } else {
          showSnack(context, text, error: true);
        }
      case 'steer_applied':
        final steer = _pendingSteers.remove(frame['id']);
        if (steer != null) setState(() => steer.steer = _SteerState.delivered);
      case 'steer_missed':
        // Not streaming any more: send it as a turn now. Otherwise it stays
        // pending and goes out with the leftovers when the turn ends.
        if (!_streaming) _resendLeftovers();
      case 'done':
        final name = frame['session_name'];
        _finishTurn();
        if (name != null) setState(() => _title = str(name));
        _resendLeftovers();
      case 'cancelled':
        if (msg != null) msg.interrupted = true;
        _finishTurn();
        _dropLeftovers();
      case 'auth_error':
        showSnack(context, str(frame['text'], 'Your session ended.'), error: true);
      case 'closed':
        _sub?.cancel();
        _sub = null;
        _conn = null;
        if (msg != null) {
          msg.error ??= 'The connection dropped before the answer finished.';
          msg.interrupted = true;
          _finishTurn();
        }
        _dropLeftovers();
    }
  }

  void _finishTurn() {
    setState(() {
      _current?.streaming = false;
      _current = null;
    });
  }

  void _resendLeftovers() {
    if (_pendingSteers.isEmpty) return;
    final items = _pendingSteers.values.toList();
    _pendingSteers.clear();
    for (final m in items) {
      m.steer = null;
      m.steerId = null;
    }
    _startTurn(items.map((m) => m.text).join('\n\n'), existing: items.last);
  }

  void _dropLeftovers() {
    if (_pendingSteers.isEmpty) return;
    setState(() {
      for (final m in _pendingSteers.values) {
        m.steer = _SteerState.notDelivered;
      }
      _pendingSteers.clear();
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_streaming && _conn != null) {
      final id = ++_steerSeq;
      final msg = _Msg.user(text, steerId: id)..steer = _SteerState.queued;
      setState(() {
        _pendingSteers[id] = msg;
        _messages.insert(_messages.indexOf(_current!), msg);
      });
      _conn!.send({'type': 'steer', 'id': id, 'text': text});
      _followEnd(force: true);
      return;
    }
    await _startTurn(text);
  }

  Future<void> _startTurn(String text, {_Msg? existing}) async {
    final reply = _Msg.assistant()..streaming = true;
    setState(() {
      if (existing == null) _messages.add(_Msg.user(text));
      _messages.add(reply);
      _current = reply;
    });
    _followEnd(force: true);
    final conn = await _ensureConnection();
    if (!mounted) return;
    if (conn == null) {
      setState(() {
        reply.error = "Couldn't connect to the assistant. Check your network and try again.";
        reply.streaming = false;
        _current = null;
      });
      return;
    }
    conn.send({
      'query': text,
      'chat_session_uuid': widget.sessionId,
      'model_name': _model,
      'agent_mode': _mode,
      'data_source': 'network_agent',
    });
  }

  void _stop() => _conn?.send({'type': 'cancel'});

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _followEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (force || pos.maxScrollExtent - pos.pixels < 160) {
        _scroll.animateTo(pos.maxScrollExtent, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickModel() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Nexus.panel,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Model', style: TextStyle(color: Nexus.textSecondary, fontWeight: FontWeight.w600)),
          ),
          for (final m in _models)
            ListTile(
              title: Text(str(m['label'], str(m['id'])), style: const TextStyle(color: Nexus.text)),
              subtitle: m['custom'] == true
                  ? const Text('Your model', style: TextStyle(color: Nexus.textDim, fontSize: 12))
                  : null,
              trailing: m['id'] == _model ? const Icon(Icons.check, color: Nexus.blueLight) : null,
              onTap: () => Navigator.pop(ctx, str(m['id'])),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _model = picked);
    await context.read<AppState>().prefs.setChatModel(picked);
  }

  String get _modelLabel {
    final m = _models.where((m) => m['id'] == _model).firstOrNull;
    return m == null ? 'Model' : str(m['label'], str(m['id']));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Nexus.bg,
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
              backgroundColor: Nexus.panel,
              shape: const Border(bottom: BorderSide(color: Nexus.border)),
            ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Mode',
              color: Nexus.raised,
              initialValue: _mode,
              icon: Icon(_mode == 'tshoot' ? Icons.healing : Icons.auto_awesome_outlined,
                  color: _mode == 'tshoot' ? Nexus.amber : Nexus.blueLight),
              onSelected: (v) => setState(() => _mode = v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'general',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome_outlined),
                    title: Text('General'),
                    subtitle: Text('Everyday questions and lookups'),
                  ),
                ),
                PopupMenuItem(
                  value: 'tshoot',
                  child: ListTile(
                    leading: Icon(Icons.healing),
                    title: Text('Troubleshoot'),
                    subtitle: Text('Step-by-step diagnosis of a problem'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Loading()
            : _loadError != null
                ? ErrorView(_loadError!, onRetry: _load)
                : Column(children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? const CenterMessage(
                              icon: Icons.auto_awesome,
                              title: 'What do you need?',
                              body: 'e.g. "Where is 10.1.2.3 plugged in?" or "Show free ports on SW-123".',
                            )
                          : ListView.builder(
                              controller: _scroll,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) => _MessageView(msg: _messages[i]),
                            ),
                    ),
                    _composer(),
                  ]),
      ),
    );
  }

  Widget _composer() {
    final hasText = _input.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Nexus.panel,
        border: Border(top: BorderSide(color: Nexus.border)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _models.length > 1 ? _pickModel : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.memory, size: 14, color: Nexus.textDim),
                  const SizedBox(width: 4),
                  Text(_modelLabel, style: const TextStyle(color: Nexus.textSecondary, fontSize: 12)),
                  if (_models.length > 1) const Icon(Icons.expand_more, size: 16, color: Nexus.textDim),
                ]),
              ),
            ),
            const Spacer(),
            if (_mode == 'tshoot')
              const Text('Troubleshoot mode', style: TextStyle(color: Nexus.amber, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Nexus.text),
                decoration: InputDecoration(
                  hintText: _streaming ? 'Working… type to redirect it' : 'Message NetSmart AI…',
                  fillColor: Nexus.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Nexus.borderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Nexus.blue),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_streaming && !hasText)
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Nexus.red),
                tooltip: 'Stop',
                icon: const Icon(Icons.stop, color: Colors.white),
                onPressed: _stop,
              )
            else
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: hasText ? Nexus.blue : Nexus.raised),
                tooltip: _streaming ? 'Send into the running answer' : 'Send',
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: hasText ? _send : null,
              ),
          ]),
        ]),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.msg});

  final _Msg msg;

  @override
  Widget build(BuildContext context) => msg.fromUser ? _user(context) : _assistant(context);

  Widget _user(BuildContext context) {
    final steer = msg.steer;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 48, bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Opacity(
            opacity: steer == _SteerState.queued ? 0.62 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: Nexus.userBubble,
                borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
                border: steer == _SteerState.queued ? const Border(right: BorderSide(color: Nexus.amber, width: 3)) : null,
              ),
              child: SelectableText(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
          if (steer != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                switch (steer) {
                  _SteerState.queued => 'queued — reaches the assistant at its next step',
                  _SteerState.delivered => 'delivered',
                  _SteerState.notDelivered => 'not delivered',
                },
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: switch (steer) {
                    _SteerState.queued => Nexus.amber,
                    _SteerState.delivered => Nexus.green,
                    _SteerState.notDelivered => Nexus.textDim,
                  },
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _assistant(BuildContext context) {
    final waiting = msg.streaming && msg.text.isEmpty && msg.tools.every((t) => !t.running);
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 10, top: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Nexus.blue, Nexus.purple]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (msg.tools.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [for (final t in msg.tools) _ToolChip(tool: t)]),
              ),
            if (msg.text.isNotEmpty)
              MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: _markdownStyle(context),
                onTapLink: (text, href, title) {
                  final uri = href == null ? null : Uri.tryParse(href);
                  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Nexus.blueLight)),
              ),
            if (msg.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(msg.error!, style: const TextStyle(color: Nexus.red, fontSize: 13.5)),
              ),
            if (msg.interrupted && msg.error == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Stopped', style: TextStyle(color: Nexus.textDim, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
          ]),
        ),
      ]),
    );
  }

  static MarkdownStyleSheet _markdownStyle(BuildContext context) {
    const body = TextStyle(color: Nexus.text, fontSize: 15, height: 1.45);
    final code = NS.mono.copyWith(color: Nexus.cyan, fontSize: 13);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      listBullet: body,
      strong: const TextStyle(color: Nexus.text, fontWeight: FontWeight.w700),
      em: const TextStyle(color: Nexus.text, fontStyle: FontStyle.italic),
      a: const TextStyle(color: Nexus.blueLight, decoration: TextDecoration.underline),
      h1: const TextStyle(color: Nexus.text, fontSize: 20, fontWeight: FontWeight.w700),
      h2: const TextStyle(color: Nexus.text, fontSize: 18, fontWeight: FontWeight.w700),
      h3: const TextStyle(color: Nexus.text, fontSize: 16, fontWeight: FontWeight.w700),
      code: code.copyWith(backgroundColor: Nexus.surface),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: Nexus.bgDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Nexus.border),
      ),
      blockquote: const TextStyle(color: Nexus.textSecondary),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Nexus.borderStrong, width: 3)),
      ),
      tableHead: const TextStyle(color: Nexus.text, fontWeight: FontWeight.w600, fontSize: 13.5),
      tableBody: const TextStyle(color: Nexus.text, fontSize: 13.5),
      tableBorder: TableBorder.all(color: Nexus.borderStrong),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      horizontalRuleDecoration: const BoxDecoration(border: Border(top: BorderSide(color: Nexus.border))),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final color = tool.running ? Nexus.cyan : (tool.failed ? Nexus.red : Nexus.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Nexus.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (tool.running)
          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
        else
          Icon(tool.failed ? Icons.close : Icons.check, size: 12, color: color),
        const SizedBox(width: 6),
        Text(tool.name, style: NS.mono.copyWith(color: Nexus.textSecondary, fontSize: 11.5)),
      ]),
    );
  }
}
