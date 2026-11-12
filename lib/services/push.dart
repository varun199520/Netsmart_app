import 'dart:io';

import 'package:flutter/services.dart';

/// APNs device token via the native bridge in ios/Runner/AppDelegate.swift.
/// Android (FCM) is not wired up yet, so it reports unsupported.
class PushService {
  static const _channel = MethodChannel('org.stanfordmed.netsmart/push');

  static bool get supported => Platform.isIOS;

  /// Asks for notification permission and returns the device token,
  /// or null if the user declined.
  static Future<String?> requestToken() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('requestToken');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
