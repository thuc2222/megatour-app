// lib/services/wishlist_service.dart

import '../config/api_config.dart';
import '../models/service_models.dart';
import 'api_service.dart';

class WishlistService {
  final ApiService _apiService = ApiService();

  // Get wishlist
  Future<List<ServiceModel>> getWishlist() async {
    try {
      final response = await _apiService.get(
        ApiConfig.wishlist,
        requiresAuth: true,
      );

      final data = response['data'] as List?;
      if (data == null) return [];

      return data.map((item) {
        // The service object is nested
        final serviceData = item['service'] ?? item;
        return ServiceModel.fromJson(serviceData);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load wishlist: ${e.toString()}');
    }
  }

  // Add to wishlist
  Future<bool> addToWishlist({
    required String serviceType,
    required int serviceId,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConfig.wishlistAdd(serviceType, serviceId),
        requiresAuth: true,
      );

      return response['status'] == true || 
             response['status'] == 1 ||
             response['class'] == 'active';
    } catch (e) {
      throw Exception('Failed to add to wishlist: ${e.toString()}');
    }
  }

  // Remove from wishlist
  Future<bool> removeFromWishlist({
    required String serviceType,
    required int serviceId,
  }) async {
    try {
      final response = await _apiService.delete(
        ApiConfig.wishlistRemove(serviceType, serviceId),
        requiresAuth: true,
      );

      return response['status'] == true || 
             response['status'] == 1 ||
             response['class'] == 'active';
    } catch (e) {
      throw Exception('Failed to remove from wishlist: ${e.toString()}');
    }
  }

  // Clear all wishlist
  Future<bool> clearWishlist() async {
    try {
      final response = await _apiService.delete(
        ApiConfig.wishlistRemoveAll,
        requiresAuth: true,
      );

      return response['status'] == true || response['status'] == 1;
    } catch (e) {
      throw Exception('Failed to clear wishlist: ${e.toString()}');
    }
  }
}