import '../config/api_config.dart';
import '../models/service_models.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';

class ServiceApi {
  final ApiService _apiService = ApiService();

  // ---------------------------------------------------------------------------
  // Core Methods
  // ---------------------------------------------------------------------------

  /// Get home page data
  Future<HomePageData> getHomePage() async {
    try {
      final response = await _apiService.get(ApiConfig.homePage);
      return HomePageData.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load home page: $e');
    }
  }

  /// Get service detail (Typed Model)
  Future<ServiceModel> getServiceDetail({
    required String serviceType,
    required int id,
  }) async {
    try {
      final endpoint = _getDetailEndpoint(serviceType, id);
      final response = await _apiService.get(endpoint);

      if (response is Map && response['data'] != null) {
        return ServiceModel.fromJson(response['data']);
      }

      return ServiceModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load service detail: $e');
    }
  }

  /// Get service detail (Raw JSON)
  Future<Map<String, dynamic>> getServiceDetailRaw({
    required int id,
    required String serviceType,
  }) async {
    try {
      final endpoint = _getDetailEndpoint(serviceType, id);
      final response = await _apiService.get(endpoint);
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load raw service detail: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Booking & Availability
  // ---------------------------------------------------------------------------

  /// Check availability
  Future<Map<String, dynamic>?> checkAvailability({
    required int id,
    required String serviceType,
    required String start,
    required String end,
    int adults = 1,
    int children = 0,
  }) async {
    try {
      final endpoint = _getAvailabilityEndpoint(serviceType, id);
      return await _apiService.get(
        endpoint,
        queryParameters: {
          'id': id,
          'start_date': start,
          'end_date': end,
          'adults': adults,
          'children': children,
        },
      );
    } catch (e) {
      throw Exception('Failed to check availability: $e');
    }
  }

  Future<Map<String, dynamic>> createBooking({
  required String objectModel,
  required int objectId,
  required String startDate,
  required String endDate,
  int adults = 1,
  int children = 0,
  required Map<int, int> items,
}) async {

  // ✅ Filter out zero-quantity rooms safely
  final filteredItems = Map.fromEntries(
    items.entries.where((e) => e.value > 0),
  );

  return await _apiService.post(
    'booking/create',
    body: {
      'object_model': objectModel,
      'object_id': objectId,
      'start_date': startDate,
      'end_date': endDate,
      'adults': adults,
      'children': children,
      'items': filteredItems.map(
        (key, value) => MapEntry(
          key.toString(),
          {'number': value},
        ),
      ),
    },
  );
}



  /// Add booking to cart
  Future<dynamic> sendBookingGet(Map<String, dynamic> params) async {
  final dio = Dio(
    BaseOptions(
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final response = await dio.get(
    "https://megatour.vn/api/booking/addToCart",
    queryParameters: params,
  );

  return response.data;
}


  /// Checkout booking
  Future<dynamic> doCheckout(String bookingCode) async {
    try {
      return await _apiService.get('booking/$bookingCode/checkout');
    } catch (e) {
      throw Exception('Failed to checkout booking: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Search & Locations
  // ---------------------------------------------------------------------------

  /// Search services
  Future<SearchResponse> searchServices({
    required String serviceType,
    String? serviceName,
    int? locationId,
    String? priceRange,
    List<int>? reviewScore,
    String? orderBy,
    int limit = 9,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'page': page,
      };

      if (serviceName?.isNotEmpty == true) {
        queryParams['service_name'] = serviceName;
      }
      if (locationId != null) {
        queryParams['location_id'] = locationId;
      }
      if (priceRange != null) {
        queryParams['price_range'] = priceRange;
      }
      if (reviewScore != null && reviewScore.isNotEmpty) {
        queryParams['review_score[]'] = reviewScore;
      }
      if (orderBy != null) {
        queryParams['orderby'] = orderBy;
      }

      final endpoint = _getSearchEndpoint(serviceType);
      final response = await _apiService.get(endpoint, queryParameters: queryParams);

      return SearchResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search $serviceType: $e');
    }
  }

  /// Get locations list
  Future<List<LocationModel>> getLocations({String? serviceName}) async {
    try {
      final response = await _apiService.get(
        ApiConfig.locations,
        queryParameters:
            serviceName?.isNotEmpty == true ? {'service_name': serviceName} : null,
      );

      final data = response['data'] as List?;
      if (data == null) return [];

      return data.map((e) => LocationModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load locations: $e');
    }
  }

  /// Get reviews for a service (hotel, tour, etc.)
Future<List<dynamic>> getReviews({
  required int serviceId,
  required String serviceType,
}) async {
  try {
    final response = await _apiService.get(
      'review',
      queryParameters: {
        'service_id': serviceId,
        'service_type': serviceType,
      },
    );

    // BookingCore returns reviews in `data`
    if (response is Map && response['data'] is List) {
      return response['data'];
    }
    return [];
  } catch (e) {
    throw Exception('Failed to load reviews: $e');
  }
}


  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------

  String _getSearchEndpoint(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'hotel':
        return ApiConfig.hotelSearch;
      case 'tour':
        return ApiConfig.tourSearch;
      case 'space':
        return ApiConfig.spaceSearch;
      case 'car':
        return ApiConfig.carSearch;
      case 'event':
        return ApiConfig.eventSearch;
      case 'boat':
        return ApiConfig.boatSearch;
      case 'flight':
        return ApiConfig.flightSearch;
      default:
        return ApiConfig.servicesSearch;
    }
  }

  String _getDetailEndpoint(String serviceType, int id) {
    switch (serviceType.toLowerCase()) {
      case 'hotel':
        return ApiConfig.hotelDetail(id);
      case 'tour':
        return ApiConfig.tourDetail(id);
      case 'space':
        return ApiConfig.spaceDetail(id);
      case 'car':
        return ApiConfig.carDetail(id);
      case 'event':
        return ApiConfig.eventDetail(id);
      case 'boat':
        return ApiConfig.boatDetail(id);
      case 'flight':
        return ApiConfig.flightDetail(id);
      default:
        throw Exception('Invalid service type: $serviceType');
    }
  }

  String _getAvailabilityEndpoint(String serviceType, int id) {
    switch (serviceType.toLowerCase()) {
      case 'hotel':
        return ApiConfig.hotelAvailability(id);
      case 'tour':
        return ApiConfig.tourAvailability(id);
      case 'space':
        return ApiConfig.spaceAvailability(id);
      case 'car':
        return ApiConfig.carAvailability(id);
      case 'event':
        return ApiConfig.eventAvailability(id);
      case 'boat':
        return ApiConfig.boatAvailability(id);
      default:
        throw Exception('Availability not supported for $serviceType');
    }
  }
}
