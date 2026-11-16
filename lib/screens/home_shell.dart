import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../widgets/nav_drawer.dart';
import 'chat_list_screen.dart';
import 'dhcp_screen.dart';
import 'more_screen.dart';
import 'search_screen.dart';
import 'tools/tool_router.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  int _index = 0;
  List<String> _tabIds = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadNav();
    });
  }

  bool _selectTab(String id) {
    final i = _tabIds.indexOf(id);
    if (i < 0) return false;
    setState(() => _index = i);
    return true;
  }

  void _openItem(Json item) {
    _scaffold.currentState?.closeDrawer();
    openNavItem(_scaffold.currentContext ?? context, item, selectTab: _selectTab);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabs = <(String, NavigationDestination, Widget)>[
      (
        'tracker',
        const NavigationDestination(icon: Icon(Icons.search), label: 'Tracker'),
        const SearchScreen(),
      ),
      if (state.can('chat'))
        (
          'chat',
          const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Assistant'),
          const ChatListScreen(),
        ),
      if (state.can('dhcp'))
        (
          'dhcp',
          const NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: 'DHCP'),
          const DhcpScreen(),
        ),
      (
        'more',
        const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        const MoreScreen(),
      ),
    ];
    _tabIds = [for (final t in tabs) t.$1];
    final index = _index.clamp(0, tabs.length - 1);
    return NavScope(
      openDrawer: () => _scaffold.currentState?.openDrawer(),
      openItem: _openItem,
      child: Scaffold(
        key: _scaffold,
        drawer: NavDrawer(onSelect: _openItem),
        drawerEdgeDragWidth: 28,
        body: IndexedStack(index: index, children: [for (final t in tabs) t.$3]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          height: 64,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [for (final t in tabs) t.$2],
        ),
      ),
    );
  }
}
