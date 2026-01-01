import 'package:flutter/material.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';

class HomeProvider extends ChangeNotifier {
  final ServiceApi _serviceApi = ServiceApi();

  HomePageData? _homeData;
  bool _isLoading = false;
  String? _errorMessage;

  HomePageData? get homeData => _homeData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Helper to check if we actually have content to show
  bool get hasData {
    if (_homeData == null) return false;
    return (_homeData!.featuredHotels?.isNotEmpty ?? false) ||
           (_homeData!.featuredTours?.isNotEmpty ?? false) ||
           (_homeData!.featuredSpaces?.isNotEmpty ?? false) ||
           (_homeData!.featuredCars?.isNotEmpty ?? false);
  }

  Future<void> loadHomeData() async {
    _isLoading = true;
    _errorMessage = null;
    // Don't notify listeners here if you want to keep old data visible while refreshing
    notifyListeners();

    try {
      final response = await _serviceApi.getHomePage();
      
      if (response != null) {
        _homeData = response;
        _errorMessage = null;
      } else {
        _errorMessage = "No data received from server";
      }
      
    } catch (e, stacktrace) {
      // This will show you exactly which field in service_models.dart failed to parse
      _errorMessage = "Data parsing error. Check console.";
      debugPrint("--- HomeProvider Error ---");
      debugPrint("Exception: $e");
      debugPrint("Stacktrace: $stacktrace");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadHomeData();
  }
}