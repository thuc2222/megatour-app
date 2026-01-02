import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GuestBookingStorage {
  static const _key = 'guest_bookings';

  static Future<void> saveBooking({
    required String bookingCode,
    required String serviceType,
    required String serviceName,
    required String startDate,
    required String endDate,
    required String total,
    String? imageUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final List list =
        jsonDecode(prefs.getString(_key) ?? '[]');

    list.insert(0, {
      'booking_code': bookingCode,
      'object_model': serviceType,
      'service_title': serviceName,
      'start_date': startDate,
      'end_date': endDate,
      'total_formatted': total,
      'status': 'pending',
      'service_icon': imageUrl,
    });

    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
