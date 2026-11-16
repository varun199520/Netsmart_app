import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../config.dart';
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

/// Opens a link to another site (e.g. NetSmart DCM) in an in-app browser
/// sheet (SFSafariViewController / Custom Tab) so the user stays in the app.
/// The one-time web ticket only signs in to the NetSmart host, so these use
/// their own login. Falls back to the system browser if the sheet can't open.
Future<bool> openOffsite(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {}
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens a sidebar item: switches tab, pushes the native screen, opens an
/// external link in an in-app browser sheet, or shows the web page signed-in
/// inside the app.
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
  final uri = Uri.tryParse(url);
  final partner = uri != null && AppConfig.isPartnerSite(uri);
  if (item['external'] == true && url.isNotEmpty && !partner) {
    final ok = await openOffsite(Uri.parse(url));
    if (!ok && context.mounted) showSnack(context, "Couldn't open $url", error: true);
    return;
  }
  final path = str(item['path']);
  if (path.isEmpty && !partner) return;
  if (state.isDemo) {
    showSnack(context, '$title opens the NetSmart website, which needs a real sign-in. '
        'Demo mode includes the native screens only.');
    return;
  }
  await state.prefs.addRecentTool(item);
  if (context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => partner ? WebToolScreen(title: title, url: uri) : WebToolScreen(title: title, path: path)));
  }
}
