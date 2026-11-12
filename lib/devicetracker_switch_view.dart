import 'dart:io';  // Import dart:io to check the platform
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';  // Import Cupertino widgets
import '/models/device_model.dart';
import 'api_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:responsive_text_widget/responsive_text_widget.dart';

class DeviceBySwitchPage extends StatefulWidget {
  String switchName = "STNNWK-21-SA01";

  DeviceBySwitchPage({required this.switchName});

  @override
  _DeviceBySwitchPageState createState() => _DeviceBySwitchPageState();
}

class _DeviceBySwitchPageState extends State<DeviceBySwitchPage> {
  late Future<List<Device>> futureDevices;

  @override
  void initState() {
    super.initState();
    futureDevices = ApiService().fetchDevicesBySwitchID(widget.switchName);
  }

  String getTimeAgo(DateTime lastSeen) {
    return timeago.format(lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Search',
        middle: Text("My Routers"),
      ),
      child: buildBody(),
    ) : Scaffold(
      appBar: AppBar(
        title: Text("My Routers"),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    return FutureBuilder<List<Device>>(
      future: futureDevices,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Platform.isIOS ? CupertinoActivityIndicator() : CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No devices found. Pull might be in progress.'));
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var item = snapshot.data![index];
              return platformAwareCard(item);
            },
          );
        }
      },
    );
  }

  Widget platformAwareCard(Device item) {
    if (!Platform.isIOS) {
      return CupertinoFormRow(
        child: CupertinoFormSection.insetGrouped(
          children: [
            buildCupertinoListTile(item),
          ],
        ),
      );
    } else {
      return Card(
        margin: EdgeInsets.all(10.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: buildCupertinoListTile(item),
      );
    }
  }

  Widget buildMaterialListTile(Device item) {
    return ListTile(
      leading: Icon(Icons.device_hub, color: Colors.blue),
      title: Text(
        item.switchName,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle:Row(children:  buildDeviceDetails(item)),
    );
  }

  Widget buildCupertinoListTile(Device item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buildDeviceDetails(item),
    );
  }

  List<Widget> buildDeviceDetails(Device item) {
    return [
      // Repeat similar layout as in Material Design for device details
      Text("IP: ${item.ip}"),
      Text("MAC: ${item.mac}"),
      Text("Last Seen: ${getTimeAgo(item.lastSeen)}"),
      Text("VLAN: ${item.vlan}"),
      Text("Port: ${item.port}"),
      ResponsiveText(text: "${item.deviceName}"),
    ];
  }
}
