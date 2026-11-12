import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:netsmart/pulltimer_widget.dart';
import 'package:netsmart/freeswitchport_view.dart';

class SwitchportInputWidget extends StatefulWidget {
  const SwitchportInputWidget({super.key});

  @override
  State<SwitchportInputWidget> createState() => _SwitchportInputWidgetState();
}

class _SwitchportInputWidgetState extends State<SwitchportInputWidget> {
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
                const SizedBox(height: 50),
                DataPullTimer(),
                const SizedBox(height: 20),
                const Text(
                  'Free Switch Port Lookup by Device Name',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FreeSwitchportView(deviceName: _controller.text),
                        ),
                      );
                    }
                  },
                  child: const Text('Search'),
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
        middle: Text('SwitchPort Lookup by Device Name'),
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
                const SizedBox(height: 20),
                CupertinoTextField(
                  controller: _controller,
                  placeholder: 'Enter Device Name',
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
                          builder: (context) => FreeSwitchportView(deviceName: _controller.text),
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
