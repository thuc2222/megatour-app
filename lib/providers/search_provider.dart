// lib/providers/search_provider.dart

import 'package:flutter/material.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';

class SearchProvider extends ChangeNotifier {
  final ServiceApi _serviceApi = ServiceApi();

  List<ServiceModel> _services = [];
  List<LocationModel> _locations = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  String _currentServiceType = 'hotel';

  List<ServiceModel> get services => _services;
  List<LocationModel> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMorePages => _currentPage < _totalPages;

  // Search services
  Future<void> searchServices({
    required String serviceType,
    String? serviceName,
    int? locationId,
    String? priceRange,
    List<int>? reviewScore,
    String? orderBy,
    int limit = 9,
    bool loadMore = false,
  }) async {
    try {
      if (!loadMore) {
        _isLoading = true;
        _services = [];
        _currentPage = 1;
        _currentServiceType = serviceType;
      }
      
      _errorMessage = null;
      notifyListeners();

      final response = await _serviceApi.searchServices(
        serviceType: serviceType,
        serviceName: serviceName,
        locationId: locationId,
        priceRange: priceRange,
        reviewScore: reviewScore,
        orderBy: orderBy,
        limit: limit,
        page: loadMore ? _currentPage + 1 : 1,
      );

      if (loadMore) {
        _services.addAll(response.data);
        _currentPage++;
      } else {
        _services = response.data;
        _currentPage = response.currentPage;
      }

      _totalPages = response.lastPage;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Load more services
  Future<void> loadMore() async {
    if (!hasMorePages || _isLoading) return;
    
    await searchServices(
      serviceType: _currentServiceType,
      loadMore: true,
    );
  }

  // Load locations
  Future<void> loadLocations({String? serviceName}) async {
    try {
      _locations = await _serviceApi.getLocations(serviceName: serviceName);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Clear search
  void clearSearch() {
    _services = [];
    _currentPage = 1;
    _totalPages = 1;
    _errorMessage = null;
    notifyListeners();
  }
}