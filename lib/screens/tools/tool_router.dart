import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';
import '../web_tool_screen.dart';
import 'lookup_screens.dart';
import 'ops_screens.dart';
import 'subnet_calc_screen.dart';
import 'switch_tools_screens.dart';

/// Sidebar items the server marks `native: <id>` that are bottom tabs.
const tabTools = {'tracker', 'chat', 'dhcp'};

/// Sidebar items with a native screen in this app version. Anything else
/// (or a `native` id this version doesn't know) opens the web page in-app.
final Map<String, Widget Function()> nativeTools = {
  'subnet_calculator': () => const SubnetCalcScreen(),
  'subnet_lookup': () => const SubnetLookupScreen(),
  'ip_mac_lookup': () => const IpMacLookupScreen(),
  'dns_lookup': () => const DnsLookupScreen(),
  'dc_vlans': () => const DcVlanScreen(),
  'ping': () => const PingScreen(),
  'port_usage': () => const PortUsageScreen(),
  'nurse_call': () => const NurseCallScreen(),
  'site_locations': () => const SitesScreen(),
  'change_requests': () => const ChangeRequestsScreen(),
  'team_calendar': () => const TeamCalendarScreen(),
};

/// Opens a sidebar item: switches tab, pushes the native screen, opens an
/// external link in Safari, or shows the web page signed-in inside the app.
Future<void> openNavItem(BuildContext context, Json item, {bool Function(String tab)? selectTab}) async {
  final state = context.read<AppState>();
  final native = str(item['native']);
  final title = str(item['title'], 'NetSmart');

  if (tabTools.contains(native) && selectTab != null && selectTab(native)) {
    await state.prefs.addRecentTool(item);
    return;
  }
  final builder = nativeTools[native];
  if (builder != null) {
    await state.prefs.addRecentTool(item);
    if (context.mounted) await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => builder()));
    return;
  }
  final url = str(item['url']);
  if (item['external'] == true && url.isNotEmpty) {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showSnack(context, "Couldn't open $url", error: true);
    return;
  }
  final path = str(item['path']);
  if (path.isEmpty) return;
  if (state.isDemo) {
    showSnack(context, '$title opens the NetSmart website, which needs a real sign-in. '
        'Demo mode includes the native screens only.');
    return;
  }
  await state.prefs.addRecentTool(item);
  if (context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WebToolScreen(title: title, path: path)));
  }
}
