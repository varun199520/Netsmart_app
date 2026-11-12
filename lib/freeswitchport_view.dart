import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '/models/switchport_model.dart';
import 'api_service.dart';

class FreeSwitchportView extends StatefulWidget {
  String deviceName = "STNNWK-21-SA01";
  FreeSwitchportView({required this.deviceName});

  @override
  _FreeSwitchportViewState createState() => _FreeSwitchportViewState();
}

class _FreeSwitchportViewState extends State<FreeSwitchportView>
    with SingleTickerProviderStateMixin {
  late Future<SwitchData> futureSwitchData;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    futureSwitchData = ApiService().fetchSwitchportData(widget.deviceName);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Free Switch Ports'),
        previousPageTitle: 'Search',
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Material(
              color: Colors
                  .white, // Optional: set a background color for the tab bar
              child: TabBar(
                controller: _tabController,
                labelColor: CupertinoColors.activeBlue, // Active tab color
                unselectedLabelColor:
                    CupertinoColors.inactiveGray, // Inactive tab color
                tabs: [
                  Tab(text: 'Device Details'),
                  Tab(text: 'Free Ports'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  buildPortsTab(),
                  buildDetailsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(
      {required IconData icon,
      required String text,
      required String dataText,
      required Color iconColor}) {
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.grey[200], // Background color for each row
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor),
              SizedBox(width: 12),
              Text(text,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 8.0),
          child: Text(dataText,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
      ],
    );
  }

  Widget buildPortsTab() {
    // This assumes you have a method to build the ports tab
    return FutureBuilder<SwitchData>(
      future: futureSwitchData,
      builder: (context, snapshot) {
        // Your existing ports tab code here
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          SwitchData? data = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Switch Name: ${data!.switchName}",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 16),
              Table(
                border: TableBorder.all(
                    color: Colors
                        .grey[300]!), // Adds a light border around the table
                children: [
                  _buildTableRow(
                    icon: Icons.access_time,
                    text: "Switch UpTime:",
                    dataText: data.switchUptime,
                    iconColor: Colors.blue,
                  ),
                  _buildTableRow(
                    icon: Icons.device_hub,
                    text: "Total Port Count:",
                    dataText: "${data.totalPortCount}",
                    iconColor: Colors.green,
                  ),
                  _buildTableRow(
                    icon: Icons.check_circle,
                    text: "Total Ports Used:",
                    dataText: "${data.totalPortUsed}",
                    iconColor: Colors.red,
                  ),
                  _buildTableRow(
                    icon: Icons.cancel,
                    text: "Total Ports\nUnused:",
                    dataText: "${data.totalPortUnused}",
                    iconColor: Colors.orange,
                  ),
                  _buildTableRow(
                    icon: Icons.portable_wifi_off,
                    text: "Unused Ports:\n(90+ Days)",
                    dataText:
                        "${data.unusedPortPercentage.toStringAsFixed(1)}%",
                    iconColor: Colors.purple,
                  ),
                  _buildTableRow(
                    icon: Icons.route_sharp,
                    text: "Used Ports:",
                    dataText: "${data.usedPortPercentage.toStringAsFixed(1)}%",
                    iconColor: Colors.teal,
                  ),
                ],
              )
            ],
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Center(child: CupertinoActivityIndicator());
        }
      },
    );
  }

  Widget buildDetailsTab() {
    // This assumes you have a method to build the details tab
    return FutureBuilder<SwitchData>(
      future: futureSwitchData,
      builder: (context, snapshot) {
        // Your existing details tab code here
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "List of Available Ports",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "Below Ports have not been used for the past 90+ days",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    itemCount: snapshot.data!.unusedPorts.length,
                    itemBuilder: (context, index) {
                      var item = snapshot.data!.unusedPorts[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.interface,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.link),
                                  SizedBox(width: 8),
                                  Text("Link Status: ${item.linkStatus}",
                                      style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time),
                                  SizedBox(width: 8),
                                  Text("Port Last Used: ${item.lastInput}",
                                      style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              ]);
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Center(child: CupertinoActivityIndicator());
        }
      },
    );
  }
}
