import 'dart:io'; // Import to use Platform.isIOS
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino widgets
import 'package:netsmart/devicetracker_mac_detail_view.dart';
import 'package:netsmart/devicetracker_switch_expanded_view.dart';
import 'package:netsmart/pulltimer_widget.dart';
import 'devicetracker_switch_view.dart';

class DeviceNameInputWidget extends StatefulWidget {
  const DeviceNameInputWidget({super.key});

  @override
  State<DeviceNameInputWidget> createState() => _DeviceNameInputWidgetState();
}

class _DeviceNameInputWidgetState extends State<DeviceNameInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? buildCupertino(context) : buildMaterial(context);
  }

  Widget buildMaterial(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 15),
                // const Text(
                //   'Wired Device Lookup By Name',
                //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                // ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Device Name',
                    hintText: 'Enter Device Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a device name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // Navigator.pushReplacement(
                        //   context,
                        //   CupertinoPageRoute(
                        //     builder: (context) =>
                        //         CupertinoDeviceListScreen(switchName: _controller.text),
                        //   ),
                        // );
                      }
                    },
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCupertino(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        previousPageTitle: 'Home',
        middle: Text('Wired Device Lookup By Switch Name'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 15),
                DataPullTimer(),
                const SizedBox(height: 20),
                CupertinoTextField(
                  controller: _controller,
                  placeholder: 'Enter Switch Name',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 20),
                CupertinoButton(
                  child: const Text('Search'),
                  color: CupertinoColors.activeBlue,
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      Navigator.push(
                        context,
                          CupertinoPageRoute(
                            builder: (context) =>
                                CupertinoDeviceListScreenExpanded(switchName: _controller.text),
                          ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
