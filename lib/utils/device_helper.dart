// lib/utils/device_helper.dart
// Optional: Use device_info_plus for real device info

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceHelper {
  static Future<String> getDeviceName() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceName;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand}_${androidInfo.model}_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name}_${iosInfo.identifierForVendor}';
      } else {
        // Fallback for other platforms
        final prefs = await SharedPreferences.getInstance();
        deviceName = prefs.getString('device_id') ?? 
                     'flutter_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceName);
      }

      return deviceName;
    } catch (e) {
      // Fallback
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
      }
      
      return deviceId;
    }
  }
}

// Then in auth_service.dart, replace _getDeviceName() with:
// Future<String> _getDeviceName() async {
//   return await DeviceHelper.getDeviceName();
// }