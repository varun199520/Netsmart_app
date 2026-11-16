import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netsmart/app_state.dart';
import 'package:netsmart/main.dart';
import 'package:netsmart/services/api.dart';
import 'package:netsmart/services/demo_api.dart';
import 'package:netsmart/services/prefs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('compareVersions', () {
    test('orders numerically, not lexically', () {
      expect(compareVersions('2.10.0', '2.9.0'), greaterThan(0));
      expect(compareVersions('2.0.0', '2.0.1'), lessThan(0));
      expect(compareVersions('2.0', '2.0.0'), 0);
      expect(compareVersions('2.0.0+5', '2.0.0'), 0);
      expect(compareVersions('1.9.9', ''), greaterThan(0));
    });
  });

  group('DemoApi', () {
    test('endpoint search finds a wired endpoint on the demo switch', () async {
      final api = DemoApi();
      final card = await api.search('192.0.2.100');
      expect(card['found'], isTrue);
      expect(jsonMap(card['wired'])['switch'], DemoApi.switchName);
    });

    test('a bounce job runs to success', () async {
      final api = DemoApi();
      final job = await api.submitJob({'kind': 'bounce', 'switch_id': DemoApi.switchId, 'port': 'GigabitEthernet1/0/1'});
      expect(job['status'], 'queued');
      await Future<void>.delayed(const Duration(milliseconds: 3700));
      final done = await api.job(str(job['id']));
      expect(done['status'], 'succeeded');
      expect(jsonMap(done['result'])['status'], 'success');
    });

    test('demo chat streams tokens, then names the session', () async {
      final api = DemoApi();
      final session = await api.createChatSession();
      final conn = await api.openChat();
      final types = <String>[];
      final done = Completer<Json>();
      conn.events.listen((e) {
        types.add(str(e['type']));
        if (e['type'] == 'done') done.complete(e);
      });
      conn.send({'query': 'where is 192.0.2.100', 'chat_session_uuid': session['id']});
      final last = await done.future.timeout(const Duration(seconds: 10));
      expect(types.first, 'tool_start');
      expect(types, contains('token'));
      expect(last['session_name'], 'where is 192.0.2.100');
      expect(jsonList((await api.chatHistory(str(session['id'])))['results']), hasLength(1));
      await conn.close();
    });
  });

  Future<void> settle(WidgetTester tester, [int steps = 4]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> startDemo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'NetSmart', packageName: 'test', version: '2.0.0', buildNumber: '1', buildSignature: '');
    final state = AppState(await Prefs.load());
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const NetSmartApp()));
    unawaited(state.enterDemo());
    await settle(tester);
  }

  testWidgets('demo mode: open a switch, bounce a port, watch the job finish', (tester) async {
    await startDemo(tester);
    await tester.tap(find.text('Switch'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'DEMO');
    await settle(tester, 3);
    await tester.tap(find.text(DemoApi.switchName));
    await settle(tester);
    expect(find.text('reachable'), findsOneWidget);
    expect(find.textContaining('endpoints'), findsWidgets);

    await tester.tap(find.text('Ports'));
    await settle(tester);
    await tester.tap(find.text('Gi1/0/1'));
    await settle(tester);
    expect(find.text('Bounce port'), findsOneWidget);
    await tester.tap(find.text('Bounce port'));
    await settle(tester, 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Bounce'));
    await settle(tester, 3);
    expect(find.text('queued'), findsOneWidget);
    // Demo jobs advance on wall-clock time, which the fake test clock doesn't move.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3800)));
    await settle(tester, 6);
    expect(find.text('succeeded'), findsOneWidget);
    expect(find.textContaining('re-enabled'), findsOneWidget);
  });

  testWidgets('demo mode: configure form loads VLANs', (tester) async {
    await startDemo(tester);
    await tester.enterText(find.byType(TextField).first, '192.0.2.100');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.settings_ethernet).first);
    await settle(tester);
    await tester.tap(find.text('Configure'));
    await settle(tester);
    expect(find.text('Access VLAN'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
  });

  testWidgets('demo mode: chat answers and renames the session', (tester) async {
    await startDemo(tester);
    await tester.tap(find.text('Assistant'));
    await settle(tester);
    await tester.tap(find.text('New chat'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'where is 192.0.2.100');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await settle(tester, 15);
    expect(find.text('search_endpoint'), findsOneWidget);
    expect(find.textContaining('demo mode'), findsWidgets);
    expect(find.widgetWithText(AppBar, 'where is 192.0.2.100'), findsOneWidget);
  });

  testWidgets('demo mode: DHCP search, reservation form and More tab render', (tester) async {
    await startDemo(tester);
    await tester.tap(find.text('DHCP'));
    await settle(tester, 1);
    await tester.enterText(find.byType(TextField).first, '192.0.2.40');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await settle(tester);
    expect(find.text('lab-printer-01'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('New reservation'));
    await settle(tester);
    expect(find.text('Switch the device plugs into'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, 2);

    await tester.tap(find.text('More'));
    await settle(tester, 2);
    expect(find.text('Demo User'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Exit demo'), 200);
    expect(find.text('Exit demo'), findsOneWidget);
    await tester.tap(find.text('My recent actions'));
    await settle(tester);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('demo mode: sidebar mirrors the web menu and opens native tools', (tester) async {
    await startDemo(tester);
    await tester.tap(find.byTooltip('NetSmart menu'));
    await settle(tester);
    expect(find.text('NETWORK OPERATIONS'), findsOneWidget);
    expect(find.text('Switch Management'), findsOneWidget);
    expect(find.text('Demo User'), findsWidgets);

    // Expand a group, open a native tool.
    await tester.tap(find.text('Switch Management'));
    await settle(tester, 2);
    await tester.tap(find.text('Nurse Call Switches'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Nurse Call Switches'), findsOneWidget);
    expect(find.text('DEMO-NCF-SW01'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, 2);

    // Search across every section; the recent list remembers the tool.
    await tester.tap(find.byTooltip('NetSmart menu'));
    await settle(tester);
    expect(find.text('RECENT'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Search tools…'), 'calc');
    await settle(tester, 1);
    expect(find.text('Security & Access › DNS & IP Management'), findsOneWidget);
    await tester.tap(find.text('Subnet Calculator'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'IP address'), '10.20.30.77/26');
    await tester.tap(find.widgetWithText(FilledButton, 'Calculate'));
    await settle(tester, 1);
    expect(find.text('10.20.30.64/26'), findsOneWidget);
    expect(find.text('10.20.30.65 – 10.20.30.126'), findsOneWidget);
    expect(find.text('255.255.255.192'), findsOneWidget);
  });

  testWidgets('demo mode: sidebar tab items switch tabs; web pages explain demo limits', (tester) async {
    await startDemo(tester);
    await tester.tap(find.byTooltip('NetSmart menu'));
    await settle(tester);
    await tester.tap(find.text('DNS & IP Management'));
    await settle(tester, 2);
    await tester.tap(find.text('IP Reservations'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'DHCP Reservations'), findsOneWidget);

    await tester.tap(find.byTooltip('NetSmart menu').hitTestable());
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search tools…'), 'guide');
    await settle(tester, 1);
    await tester.tap(find.text('User Guide'));
    await settle(tester, 2);
    expect(find.textContaining('needs a real sign-in'), findsOneWidget);
  });

  testWidgets('demo mode: NetSmart DCM is an in-app page, not an external link', (tester) async {
    await startDemo(tester);
    await tester.tap(find.byTooltip('NetSmart menu'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search tools…'), 'dcm');
    await settle(tester, 1);
    final item = find.text('NetSmart DCM').last;
    final row = find.ancestor(of: item, matching: find.byType(InkWell)).first;
    expect(find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)), findsNothing);
    expect(find.descendant(of: row, matching: find.byIcon(Icons.language)), findsOneWidget);
    await tester.tap(item);
    await settle(tester, 2);
    expect(find.textContaining('needs a real sign-in'), findsOneWidget);
  });

  testWidgets('demo mode: ping from switch runs as a job', (tester) async {
    await startDemo(tester);
    await tester.tap(find.byTooltip('NetSmart menu'));
    await settle(tester);
    await tester.tap(find.text('Switch Management'));
    await settle(tester, 2);
    await tester.tap(find.text('Ping from Switch'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'IP address to ping'), '192.0.2.100');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ping'));
    await settle(tester, 3);
    expect(find.text('Ping from switch'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3800)));
    await settle(tester, 6);
    expect(find.text('succeeded'), findsOneWidget);
    expect(find.textContaining('Success rate is 100 percent'), findsOneWidget);
  });

  testWidgets('demo mode: DNS lookup and change requests render', (tester) async {
    await startDemo(tester);
    await tester.tap(find.byTooltip('NetSmart menu'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search tools…'), 'dns lookup');
    await settle(tester, 1);
    await tester.tap(find.text('DNS Lookup'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '192.0.2.100');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await settle(tester);
    expect(find.text('workstation-00.demo.example'), findsWidgets);
    expect(find.text('missing on 1'), findsOneWidget);
    await tester.pageBack();
    await settle(tester, 2);

    await tester.tap(find.byTooltip('NetSmart menu').hitTestable());
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search tools…'), 'change');
    await settle(tester, 1);
    await tester.tap(find.text('Change Requests'));
    await settle(tester);
    expect(find.text('CHG0010001'), findsOneWidget);
    await tester.tap(find.text('CHG0010002'));
    await settle(tester);
    expect(find.text('Affected devices'.toUpperCase()), findsOneWidget);
  });

  testWidgets('demo mode: search an endpoint from the tracker tab', (tester) async {
    await startDemo(tester);
    expect(find.text('Device Tracker'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '192.0.2.100');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('workstation-00'), findsOneWidget);
    expect(find.text(DemoApi.switchName), findsOneWidget);
    // Demo banner stays visible on pushed routes too.
    expect(find.textContaining('Demo mode'), findsOneWidget);
  });
}
