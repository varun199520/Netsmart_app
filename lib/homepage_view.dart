import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:netsmart/devicetracker_mac_input_widget.dart';
import 'colors.dart'; // Import your colors.dart file

class HomePage extends StatelessWidget {
  final List<CardItem> cardItems = [
    // CardItem(
    //   title: 'Chatbot',
    //   description: 'Interact with our AI-powered chatbot for assistance.',
    //   icon: Platform.isIOS ? CupertinoIcons.chat_bubble_2 : Icons.chat,
    //   routeName: '/chatbot',
    // ),
    CardItem(
      title: 'Device Tracker by Mac/IP',
      description: 'Track devices using their MAC or IP address',
      icon: Platform.isIOS
          ? CupertinoIcons.device_phone_portrait
          : Icons.device_hub,
      routeName: '/device_tracker_mac_ip',
    ),
    CardItem(
      title: 'Device Tracker by Switch Name',
      description: 'Track wired devices by switch name.',
      icon: Platform.isIOS ? CupertinoIcons.link : Icons.router,
      routeName: '/device_tracker_switch_name',
    ),
    CardItem(
      title: 'Free Switchport',
      description: 'Find available switch ports.',
      icon: Platform.isIOS
          ? CupertinoIcons.square_arrow_down_on_square
          : Icons.usb,
      routeName: '/free_switchport',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? _buildCupertinoScaffold(context)
        : _buildMaterialScaffold(context);
  }

  Widget _buildCupertinoScaffold(BuildContext context) {
    return CupertinoPageScaffold(
      // navigationBar: CupertinoNavigationBar(
      //   middle: Text('Netsmart'),
      //   backgroundColor: AppColors.primary, // App bar color: #5CB6F9
      // ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Image.asset('assets/logo.png',height: 250,width: 250),
          Flexible(
            fit: FlexFit.loose,
            child: _buildGrid(context, true))
        ]),
      ),
    );
  }

  Widget _buildMaterialScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.highlight, // Background color: #F7F7F7
      appBar: AppBar(
        title: Text('Netsmart'),
        backgroundColor: AppColors.primary, // App bar color: #5CB6F9
      ),
      body: _buildGrid(context, false),
    );
  }

  Widget _buildGrid(BuildContext context, bool isCupertino) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.66,
      ),
      itemCount: cardItems.length,
      itemBuilder: (context, index) {
        final cardItem = cardItems[index];
        return isCupertino
            ? _buildCupertinoCard(context, cardItem)
            : _buildMaterialCard(context, cardItem);
      },
    );
  }

  Widget _buildCupertinoCard(BuildContext context, CardItem cardItem) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.pushNamed(context, cardItem.routeName);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightNeutral, // Card background color: #F4F6FC
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cardItem.icon,
                  size: 48, color: AppColors.primary), // Icon color: #5CB6F9
              const SizedBox(height: 16),
              Text(
                cardItem.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary, // Text color: #365B6D
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                cardItem.description,
                style: TextStyle(
                  fontSize: 14, // Increased font size
                  color: AppColors.neutral, // Text color: #737373
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context, CardItem cardItem) {
    return Card(
      color: AppColors.lightNeutral, // Card background color: #F4F6FC
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, cardItem.routeName);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cardItem.icon,
                  size: 48, color: AppColors.primary), // Icon color: #5CB6F9
              const SizedBox(height: 16),
              Text(
                cardItem.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary, // Text color: #365B6D
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                cardItem.description,
                style: TextStyle(
                  fontSize: 14, // Increased font size
                  color: AppColors.neutral, // Text color: #737373
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardItem {
  final String title;
  final String description;
  final IconData icon;
  final String routeName;

  CardItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.routeName,
  });
}
