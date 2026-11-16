import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import '../widgets/nav_drawer.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Json>? _sessions;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<AppState>().api.chatSessions();
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(Json session) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(sessionId: str(session['id']), initialName: str(session['name'], 'New chat')),
    ));
    _load();
  }

  Future<void> _newChat() async {
    setState(() => _creating = true);
    try {
      final session = await context.read<AppState>().api.createChatSession();
      if (mounted) await _open(session);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<bool> _delete(Json session) async {
    final ok = await confirm(context,
        title: 'Delete this conversation?',
        body: str(session['name'], 'Untitled'),
        action: 'Delete',
        destructive: true);
    if (!ok || !mounted) return false;
    try {
      await context.read<AppState>().api.deleteChatSession(str(session['id']));
      setState(() => _sessions?.removeWhere((s) => s['id'] == session['id']));
      return true;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(leading: const NavMenuButton(), title: const Text('Assistant')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: Nexus.blue,
        foregroundColor: Colors.white,
        icon: _creating
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
        onPressed: _creating ? null : _newChat,
      ),
      body: _error != null && sessions == null
          ? ErrorView(_error!, onRetry: _load)
          : sessions == null
              ? const Loading()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: sessions.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          CenterMessage(
                            icon: Icons.auto_awesome,
                            title: 'Ask NetSmart AI',
                            body: 'Where is this device plugged in? Why is this port down? '
                                'Start a conversation and the assistant answers from live network data.',
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: sessions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                          itemBuilder: (context, i) {
                            final s = sessions[i];
                            return Dismissible(
                              key: ValueKey(s['id']),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _delete(s),
                              background: Container(
                                color: const Color(0xFF3D1518),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete_outline, color: NS.danger),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.chat_bubble_outline, color: Nexus.blueLight),
                                title: Text(str(s['name'], 'Untitled'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(ago(s['created_at']),
                                    style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
                                onTap: () => _open(s),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
