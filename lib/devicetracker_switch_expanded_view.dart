import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:netsmart/copy_detail_widget.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'models/device_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'api_service.dart';

class CupertinoDeviceListScreenExpanded extends StatefulWidget {
  final String switchName;

  CupertinoDeviceListScreenExpanded({required this.switchName});

  @override
  State<CupertinoDeviceListScreenExpanded> createState() => _CupertinoDeviceListScreenExpandedState();
}

class _CupertinoDeviceListScreenExpandedState extends State<CupertinoDeviceListScreenExpanded> {
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('List of End Devices'),
        previousPageTitle: 'Search',
      ),
      child: SafeArea(
        child: FutureBuilder<List<Device>>(
          future: futureDevices,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              // Convert List<Device> to Map<String, List<Device>> for accordion
              Map<String, List<Device>> deviceMap = {
                for (Device device in snapshot.data!)
                  device.ip: [device]
              };

              return Material(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SearchableList<Device>.expansion(
                    expansionListData: deviceMap,
                    expansionTitleBuilder: ( ip) => Material(
                      child: Container(
                        color: CupertinoColors.systemGrey5,
                        padding: const EdgeInsets.all(8),
                        child: Text(ip, style: TextStyle(color: CupertinoColors.black)),
                      ),
                    ),
                    filterExpansionData: (String searchText) {
                      var filteredMap = {
                        for (Device device in snapshot.data!)
                          if (device.ip.toLowerCase().contains(searchText.toLowerCase()))
                            device.ip: [device]
                      };
                      return filteredMap;
                    },
                    expansionListBuilder: (int index, Device device) {
                      return Column(
                        children: <Widget>[
                          // CupertinoListTile(title: Text('Name: ${device.deviceName.split('.')[0]}'),trailing: ClipboardButton(textToCopy: ),),
                          CupertinoListTile(title: Text('IP: ${device.ip}'),trailing: ClipboardButton(textToCopy:device.ip ),),
                          CupertinoListTile(title: Text('MAC: ${device.mac}'),trailing: ClipboardButton(textToCopy: device.mac),),
                          CupertinoListTile(title: Text('Last Seen: ${getTimeAgo(device.lastSeen)}') ),
                          CupertinoListTile(title: Text('Recent: ${device.recent ? "Yes" : "No"}')),
                          CupertinoListTile(title: Text('VLAN: ${device.vlan}'),trailing: ClipboardButton(textToCopy: device.vlan),),
                          CupertinoListTile(title: Text('Port: ${device.port}'),trailing: ClipboardButton(textToCopy:device.port ),),
                          ListTile(title: Text('Switch: ${device.switchName}')),
                        ],
                      );
                    },
                    style: const TextStyle(fontSize: 18),
                    emptyWidget: Center(child: Text("No devices found")),
                    inputDecoration: InputDecoration(
                      labelText: "Search by IP Address",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              );
            } else {
              return Center(child: Text("No data available"));
            }
          },
        ),
      ),
    );
  }
}
