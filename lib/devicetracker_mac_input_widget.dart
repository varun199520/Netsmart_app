import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:netsmart/devicetracker_mac_detail_view.dart';
import 'package:netsmart/pulltimer_widget.dart';

class IPMACInputWidget extends StatefulWidget {
  const IPMACInputWidget({super.key});

  @override
  State<IPMACInputWidget> createState() => _IPMACInputWidgetState();
}

class _IPMACInputWidgetState extends State<IPMACInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Lookup By IP or MAC Address'),
        previousPageTitle: 'Home',
      ),
      child: buildBody(context),
    ) : Scaffold(
      body: buildBody(context),
    );
  }

  Widget buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
                            SizedBox(height: 15), 

              DataPullTimer(),
              // Text(
              //   'Wired Device Lookup By IP or MAC Address',
              //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              // ),
              SizedBox(height: 20),   
              Platform.isIOS ? CupertinoTextField(
                controller: _controller,
                keyboardType: TextInputType.numberWithOptions(signed: false,decimal: true),
                placeholder: 'Enter IP or MAC Address',
                enableSuggestions: true,
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ) : TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'IP/MAC Address',
                  hintText: 'Enter IP or MAC Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an IP or MAC address';
                  }
                  final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                  final macPattern = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
                  if (!ipPattern.hasMatch(value) && !macPattern.hasMatch(value)) {
                    return 'Please enter a valid IP or MAC address';
                  } 
                  return null;
                },
              ),
              SizedBox(height: 20), 
              Platform.isIOS ? CupertinoButton(
                child: Text('Search'),
                color: CupertinoColors.activeBlue,
                onPressed: () => performSearch(context),
              ) : ElevatedButton(
                onPressed: () => performSearch(context),
                child: Text('Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void performSearch(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => DetailedView(ipOrMac: _controller.text),
        ),
      );
    }
  }
}
