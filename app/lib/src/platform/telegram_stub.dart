import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kv_store.dart';

final GlobalKey<NavigatorState> ironVibeNavigatorKey =
    GlobalKey<NavigatorState>();

class IronVibeTelegram {
  static bool get isSupported => false;
  static bool get hasDeviceStorage => false;
  static bool get hasCloudStorage => false;
  static bool get suggestsDark => false;
  static String get platform => 'none';
  static String get version => '';
  static IronVibeKvStore? cloudStore;
  static IronVibeRawStringStore? deviceRaw;
  static final NavigatorObserver navObserver = NavigatorObserver();

  static Future<void> boot() async {}

  static void applyChrome(ThemeMode mode) {}

  static Future<void> openUrl(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
