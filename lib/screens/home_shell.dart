import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'chat_list_screen.dart';
import 'dhcp_screen.dart';
import 'more_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabs = <(NavigationDestination, Widget)>[
      (
        const NavigationDestination(icon: Icon(Icons.search), label: 'Tracker'),
        const SearchScreen(),
      ),
      if (state.can('chat'))
        (
          const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Assistant'),
          const ChatListScreen(),
        ),
      if (state.can('dhcp'))
        (
          const NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: 'DHCP'),
          const DhcpScreen(),
        ),
      (
        const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        const MoreScreen(),
      ),
    ];
    final index = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in tabs) t.$2]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 64,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [for (final t in tabs) t.$1],
      ),
    );
  }
}
