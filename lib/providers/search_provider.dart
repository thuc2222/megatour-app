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

  // ================= GETTERS =================

  List<ServiceModel> get services => _services;
  List<LocationModel> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasMorePages => _currentPage < _totalPages;

  // ================= SEARCH SERVICES =================

  Future<void> searchServices({
  required String serviceType,
  String? serviceName,
  String? locationName,
  String? orderBy,
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
        locationName: serviceName,
        orderBy: orderBy,
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
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= LOAD MORE =================

  Future<void> loadMore() async {
    if (_isLoading || !hasMorePages) return;

    await searchServices(
      serviceType: _currentServiceType,
      loadMore: true,
    );
  }

  // ================= LOAD LOCATIONS =================
  // Used for autocomplete

  Future<void> loadLocations({String? keyword}) async {
    try {
      _locations = await _serviceApi.getLocations(
        serviceName: keyword,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // ================= CLEAR =================

  void clearSearch() {
    _services = [];
    _currentPage = 1;
    _totalPages = 1;
    _errorMessage = null;
    notifyListeners();
  }
}
