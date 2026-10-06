import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests every runtime permission required by the local mesh transport.
///
/// Android (Nearby Connections / Bluetooth mesh):
///  * Location          - required for discovery on Android 6 - 11
///  * Bluetooth Scan    - Android 12+
///  * Bluetooth Connect - Android 12+
///  * Bluetooth Advertise - Android 12+ (be visible to others)
///  * Nearby Wi-Fi Devices - Android 13+ (Wi-Fi Direct transport)
///
/// iOS:
///  * Bluetooth - used for peer discovery and local sessions
class PermissionService {
  const PermissionService._();

  static Future<bool> ensureMeshPermissions() async {
    try {
      if (Platform.isAndroid) return _requestAndroid();
      if (Platform.isIOS) return _requestIos();
      return true;
    } on Exception {
      return false;
    }
  }

  static Future<bool> _requestAndroid() async {
    final results = await <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    try {
      await Permission.nearbyWifiDevices.request();
    } on Exception {
      // Older Android versions do not know this permission.
    }

    final scan = results[Permission.bluetoothScan]?.isGranted ?? false;
    final connect = results[Permission.bluetoothConnect]?.isGranted ?? false;
    final advertise = results[Permission.bluetoothAdvertise]?.isGranted ?? false;
    final location = results[Permission.locationWhenInUse]?.isGranted ?? false;

    // Android 6 - 11 relies on the location grant, Android 12+ on the
    // Bluetooth runtime permissions.
    final canDiscover = scan || location;
    return canDiscover && connect && advertise;
  }

  static Future<bool> _requestIos() async {
    final results = await <Permission>[Permission.bluetooth].request();
    return results[Permission.bluetooth]?.isGranted ?? false;
  }

  static Future<void> openSettings() => openAppSettings();
}
