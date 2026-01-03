// lib/services/location_api.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/service_models.dart';
import '../configs/api_config.dart';

class LocationApi {
  /// 🔍 Location autocomplete using backend-supported `location_name`
  Future<List<LocationModel>> searchLocations(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}hotel/search'
      '?location_name=${Uri.encodeComponent(keyword)}'
      '&limit=10',
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch locations');
    }

    final jsonBody = json.decode(res.body);

    final List data = jsonBody['data'] ?? [];

    /// Extract UNIQUE locations from hotel results
    final Map<int, LocationModel> unique = {};

    for (final item in data) {
      final loc = item['location'];
      if (loc != null && loc is Map<String, dynamic>) {
        final id = loc['id'];
        if (!unique.containsKey(id)) {
          unique[id] = LocationModel.fromJson(loc);
        }
      }
    }

    return unique.values.toList();
  }
}
