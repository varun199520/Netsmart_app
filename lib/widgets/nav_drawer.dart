import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../services/api.dart';
import '../theme.dart';
import 'common.dart';

/// Lets any screen inside the home shell open the sidebar or jump to a tab.
class NavScope extends InheritedWidget {
  const NavScope({super.key, required this.openDrawer, required this.openItem, required super.child});

  final VoidCallback openDrawer;
  final void Function(Json item) openItem;

  static NavScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<NavScope>();

  @override
  bool updateShouldNotify(NavScope oldWidget) => false;
}

/// Hamburger for the AppBar of each tab; opens the NetSmart sidebar.
class NavMenuButton extends StatelessWidget {
  const NavMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = NavScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'NetSmart menu',
      icon: const Icon(Icons.menu),
      onPressed: () {
        HapticFeedback.selectionClick();
        scope.openDrawer();
      },
    );
  }
}

/// Web sidebar icons (boxicons / font-awesome class names) → Material icons.
IconData navIcon(String? name) => switch (name) {
      'bxs-brain' => Icons.psychology_outlined,
      'bxs-devices' => Icons.devices_other_outlined,
      'bx-chip' => Icons.memory,
      'bxs-bar-chart-alt-2' => Icons.bar_chart,
      'bx-server' => Icons.storage,
      'bxs-shield-alt-2' => Icons.shield_outlined,
      'fa-circle-nodes' => Icons.hub_outlined,
      'bx-transfer-alt' => Icons.swap_horiz,
      'bx-calendar-check' => Icons.event_available_outlined,
      'bx-calculator' => Icons.calculate_outlined,
      'bx-plug' => Icons.power_outlined,
      'bxs-data' => Icons.inventory_2_outlined,
      'bx-check-shield' => Icons.verified_user_outlined,
      'bx-sitemap' => Icons.account_tree_outlined,
      'bxs-cctv' => Icons.videocam_outlined,
      'bxs-buildings' => Icons.apartment,
      'bx-headphone' => Icons.headset_mic_outlined,
      'bx-phone' => Icons.phone_outlined,
      'bx-calendar' => Icons.calendar_month_outlined,
      'bxs-user-account' => Icons.manage_accounts_outlined,
      'bxs-cog' => Icons.settings_outlined,
      'bxs-book-open' => Icons.menu_book_outlined,
      _ => Icons.widgets_outlined,
    };

/// The NetSmart web sidebar, as an iOS drawer: brand, "Search tools…",
/// accent-coloured sections with collapsible groups, and the user footer.
class NavDrawer extends StatefulWidget {
  const NavDrawer({super.key, required this.onSelect});

  final void Function(Json item) onSelect;

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> {
  final _search = TextEditingController();
  final Set<String> _open = {};
  String _version = '';

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadNav();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(Json item) {
    HapticFeedback.selectionClick();
    widget.onSelect(item);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * 0.86).clamp(260.0, 340.0),
      backgroundColor: NS.bg,
      surfaceTintColor: Colors.transparent,
      shape: const Border(right: BorderSide(color: NS.borderMuted)),
      child: SafeArea(
        child: Column(children: [
          _brand(),
          _searchField(),
          Expanded(child: _body(state)),
          _footer(state),
        ]),
      ),
    );
  }

  Widget _brand() => Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NS.borderMuted))),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [NS.accent, NS.purple]),
            ),
            child: const Icon(Icons.lan_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('NetSmart',
                style: TextStyle(color: NS.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ),
        ]),
      );

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: TextField(
          controller: _search,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search tools…',
            fillColor: NS.surface,
            prefixIcon: const Icon(Icons.search, size: 18, color: NS.textDim),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(_search.clear),
                  ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NS.borderMuted)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NS.borderMuted)),
          ),
        ),
      );

  Widget _body(AppState state) {
    final nav = state.nav;
    if (nav == null) {
      if (state.navError != null) {
        return CenterMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load the menu",
          body: state.navError,
          action: OutlinedButton(onPressed: () => state.loadNav(force: true), child: const Text('Try again')),
        );
      }
      return const Loading();
    }
    final sections = jsonList(nav['sections']);
    final q = _search.text.trim().toLowerCase();
    return RefreshIndicator(
      onRefresh: () => state.loadNav(force: true),
      child: q.isEmpty ? _tree(state, sections) : _results(sections, q),
    );
  }

  Widget _tree(AppState state, List<Json> sections) {
    final recent = state.prefs.recentTools;
    return ListView(padding: const EdgeInsets.only(top: 4, bottom: 16), children: [
      if (recent.isNotEmpty) ...[
        const _SectionHeader(title: 'Recent', color: NS.textSecondary),
        for (final item in recent)
          _ItemTile(item: item, indent: 16, leading: Icons.history, onTap: () => _select(item)),
      ],
      for (final section in sections) ...[
        _SectionHeader(title: str(section['title']), color: NS.sectionAccent(str(section['accent']))),
        for (final group in jsonList(section['groups'])) ..._group(section, group),
      ],
    ]);
  }

  List<Widget> _group(Json section, Json group) {
    final key = '${section['title']}/${group['label']}';
    final open = _open.contains(key);
    final items = jsonList(group['items']);
    final accent = NS.sectionAccent(str(section['accent']));
    return [
      InkWell(
        onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
          child: Row(children: [
            Icon(navIcon(str(group['icon'])), size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(str(group['label']),
                  style: TextStyle(color: open ? NS.text : NS.textSecondary, fontSize: 15)),
            ),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.chevron_right, size: 18, color: NS.textDim),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: open
            ? Column(children: [
                for (final item in items) _ItemTile(item: item, indent: 48, onTap: () => _select(item)),
              ])
            : const SizedBox(width: double.infinity),
      ),
    ];
  }

  Widget _results(List<Json> sections, String q) {
    final hits = <(Json, String)>[];
    for (final s in sections) {
      for (final g in jsonList(s['groups'])) {
        for (final item in jsonList(g['items'])) {
          final title = str(item['title']);
          if ('$title ${g['label']} ${s['title']}'.toLowerCase().contains(q)) {
            hits.add((item, '${s['title']} › ${g['label']}'));
          }
        }
      }
    }
    if (hits.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 40),
        CenterMessage(icon: Icons.search_off, title: 'No tools match'),
      ]);
    }
    return ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
      for (final (item, path) in hits)
        _ItemTile(item: item, indent: 16, subtitle: path, onTap: () => _select(item)),
    ]);
  }

  Widget _footer(AppState state) {
    final me = state.me ?? const {};
    final name = str(me['name'], str(me['username'], '?'));
    final initials = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: NS.borderMuted))),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_version.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.commit, size: 13, color: NS.textDim),
              const SizedBox(width: 6),
              Text('v$_version', style: const TextStyle(color: NS.textDim, fontSize: 11.5)),
            ]),
          ),
        Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: NS.accent.withValues(alpha: 0.18),
            child: Text(initials, style: const TextStyle(color: NS.accent, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NS.text, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(str(me['username']), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NS.textSecondary, fontSize: 12)),
            ]),
          ),
          IconButton(
            tooltip: state.isDemo ? 'Exit demo' : 'Sign out',
            icon: const Icon(Icons.logout, size: 20, color: NS.textSecondary),
            onPressed: () async {
              if (!state.isDemo) {
                final ok = await confirm(context,
                    title: 'Sign out?', body: 'This device will need to sign in again to use NetSmart.', action: 'Sign out');
                if (!ok) return;
              }
              await state.signOut();
            },
          ),
        ]),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color.withValues(alpha: 0.85), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title.toUpperCase(),
                style: const TextStyle(color: NS.textDim, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ),
        ]),
      );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.indent, required this.onTap, this.subtitle, this.leading});

  final Json item;
  final double indent;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final native = item['native'] != null;
    // Partner sites (e.g. DCM) open in-app like web pages, so no "leaves app" icon.
    final external = item['external'] == true && !AppConfig.isPartnerSite(Uri.tryParse(str(item['url'])) ?? Uri());
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: EdgeInsets.fromLTRB(indent, 6, 14, 6),
        child: Row(children: [
          if (leading != null) ...[Icon(leading, size: 16, color: NS.textDim), const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(item['title']), style: const TextStyle(color: NS.textSecondary, fontSize: 14.5)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(color: NS.textDim, fontSize: 11.5)),
            ]),
          ),
          if (!native)
            Icon(external ? Icons.open_in_new : Icons.language, size: 14, color: NS.textDim),
        ]),
      ),
    );
  }
}
