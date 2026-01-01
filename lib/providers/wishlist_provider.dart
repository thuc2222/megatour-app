// lib/providers/wishlist_provider.dart

import 'package:flutter/material.dart';
import '../services/wishlist_service.dart';
import '../models/service_models.dart';

class WishlistProvider extends ChangeNotifier {
  final WishlistService _wishlistService = WishlistService();

  List<ServiceModel> _wishlist = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ServiceModel> get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get itemCount => _wishlist.length;

  // Check if item is in wishlist
  bool isInWishlist(int serviceId) {
    return _wishlist.any((item) => item.id == serviceId);
  }

  // Load wishlist
  Future<void> loadWishlist() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _wishlist = await _wishlistService.getWishlist();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Add to wishlist
  Future<bool> addToWishlist({
    required String serviceType,
    required int serviceId,
    ServiceModel? service,
  }) async {
    try {
      final success = await _wishlistService.addToWishlist(
        serviceType: serviceType,
        serviceId: serviceId,
      );

      if (success && service != null) {
        _wishlist.add(service);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Remove from wishlist
  Future<bool> removeFromWishlist({
    required String serviceType,
    required int serviceId,
  }) async {
    try {
      final success = await _wishlistService.removeFromWishlist(
        serviceType: serviceType,
        serviceId: serviceId,
      );

      if (success) {
        _wishlist.removeWhere((item) => item.id == serviceId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Toggle wishlist
  Future<bool> toggleWishlist({
    required String serviceType,
    required int serviceId,
    ServiceModel? service,
  }) async {
    if (isInWishlist(serviceId)) {
      return await removeFromWishlist(
        serviceType: serviceType,
        serviceId: serviceId,
      );
    } else {
      return await addToWishlist(
        serviceType: serviceType,
        serviceId: serviceId,
        service: service,
      );
    }
  }

  // Clear all wishlist
  Future<bool> clearWishlist() async {
    try {
      final success = await _wishlistService.clearWishlist();

      if (success) {
        _wishlist.clear();
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}