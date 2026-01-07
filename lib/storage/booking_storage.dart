import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookingStorage {
  static const String _key = 'bookings';

  static Future<void> save(Map<String, dynamic> booking) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.insert(0, jsonEncode(booking));
    await prefs.setStringList(_key, list);
  }

  static Future<List<Map<String, dynamic>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }
}
