import 'dart:io';  // Import dart:io to check the platform
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';  // Import Cupertino widgets
import 'package:netsmart/copy_detail_widget.dart';
import 'api_service.dart';
import '/models/device_model.dart';
import 'colors.dart';

class DetailedView extends StatelessWidget {
  final String ipOrMac;

  DetailedView({required this.ipOrMac});

  @override
  Widget build(BuildContext context) {
    return DeviceDetails(ipOrMac: ipOrMac, isIOS: true);
    if (Platform.isIOS) {
      return CupertinoApp(
        theme: CupertinoThemeData(
          primaryColor: CupertinoColors.activeBlue,
        ),
        home: DeviceDetails(ipOrMac: ipOrMac, isIOS: true),
      );
    } else {
      return MaterialApp(
        theme: ThemeData(
          primaryColor: Colors.blue,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: Colors.grey,
          ),
          textTheme: TextTheme(
            titleLarge: TextStyle(color: Colors.black),
            bodyMedium: TextStyle(color: Colors.black54),
          ),
        ),
        home: DeviceDetails(ipOrMac: ipOrMac, isIOS: false),
      );
    }
  }
}

class DeviceDetails extends StatelessWidget {
  final String ipOrMac;
  final bool isIOS;

  DeviceDetails({required this.ipOrMac, required this.isIOS});

  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
        middle: Text('Lookup By IP or MAC Address'),
              previousPageTitle:'Search'

      ),

      child: FutureBuilder<Device>(
        future: apiService.fetchDeviceByIPOrMac(ipOrMac),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: isIOS ? CupertinoActivityIndicator() : CircularProgressIndicator(color: AppColors.accent));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data found'));
          } else {
            final device = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTile('IP Address', device.ip, Icons.language),
                  buildTile('MAC Address', device.mac, Icons.memory),
                  buildTile('Device Name', device.deviceName, Icons.devices),
                  buildTile('Switch Name', device.switchName, Icons.near_me),
                  buildTile('Port Number', device.port, Icons.router),
                  buildTile('VLAN ID', device.vlan, Icons.vpn_lock),
                  buildTile('Last Seen', device.lastSeen.toString(), Icons.access_time),
                  buildTile('Recent', device.recent.toString(), Icons.update),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget buildTile(String title, String subtitle, IconData icon) {
    if (false) {
      return CupertinoFormRow(
        prefix: Icon(icon, color: CupertinoColors.activeBlue),
        child: CupertinoTextFormFieldRow(
          placeholder: title,
          initialValue: subtitle,
          readOnly: true,
        ),
      );
    } else {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.blue),
          title: Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 14)),
          trailing: ClipboardButton(textToCopy: subtitle),
        ),
      );
    }
  }
}
