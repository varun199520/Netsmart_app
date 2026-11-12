import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:netsmart/api_service.dart';
import 'package:netsmart/devicetracker_mac_detail_view.dart';
import 'package:netsmart/devicetracker_mac_input_widget.dart';
import 'package:netsmart/devicetracker_switch_input_widget.dart';
import 'package:netsmart/freeswitchport_input_widget.dart';
import 'package:netsmart/homepage_view.dart';
import 'package:netsmart/devicetracker_switch_view.dart';
import 'package:netsmart/freeswitchport_view.dart';
import 'colors.dart'; // Import your colors.dart file
import 'devicetracker_switch_expanded_view.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Device Lookup',
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],

        theme: CupertinoThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          barBackgroundColor: AppColors.primary,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        home: HomePage(), 
        routes: {
          '/device_tracker_mac_ip': (context) => IPMACInputWidget(),
          '/device_tracker_switch_name': (context) => DeviceNameInputWidget(),
          '/free_switchport': (context) => SwitchportInputWidget(),
        },
      );
    } else {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Device Lookup',
        theme: ThemeData(
          brightness: Brightness.light,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            color: AppColors.primary,
            iconTheme: IconThemeData(color: AppColors.highlight),
            titleTextStyle: TextStyle(
              color: AppColors.highlight,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          textTheme: TextTheme(
            headlineLarge: TextStyle(color: AppColors.primary),
            bodyLarge: TextStyle(color: Colors.black),
          ),
          buttonTheme: ButtonThemeData(
            buttonColor: AppColors.accent,
            textTheme: ButtonTextTheme.primary,
          ),
          iconTheme: IconThemeData(
            color: AppColors.secondary,
          ),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: AppColors.primary,
            secondary: AppColors.accent,
            background: AppColors.background,
            surface: AppColors.lightNeutral,
            onPrimary: AppColors.highlight,
            onSecondary: AppColors.neutral,
            onBackground: AppColors.neutral,
            onSurface: AppColors.neutral,
          ),
          useMaterial3: true,
        ),
        home: HomePage(),
        
        routes: {
          '/device_tracker_mac_ip': (context) => IPMACInputWidget(),
          '/device_tracker_switch_name': (context) => DeviceNameInputWidget(),
          '/free_switchport': (context) => SwitchportInputWidget(),
        },
      );
    }
  }
}
