import '../config/api_config.dart';
import '../models/service_models.dart';
import 'api_service.dart';

class ServiceApi {
  final ApiService _apiService = ApiService();

  // ---------------------------------------------------------------------------
  // CORE
  // ---------------------------------------------------------------------------

  Future<HomePageData> getHomePage() async {
    final response = await _apiService.get(ApiConfig.homePage);
    return HomePageData.fromJson(response);
  }

  Future<ServiceModel> getServiceDetail({
    required String serviceType,
    required int id,
  }) async {
    final endpoint = _getDetailEndpoint(serviceType, id);
    final response = await _apiService.get(endpoint);

    if (response is Map && response['data'] != null) {
      return ServiceModel.fromJson(response['data']);
    }

    return ServiceModel.fromJson(response);
  }

  Future<Map<String, dynamic>> getServiceDetailRaw({
    required int id,
    required String serviceType,
  }) async {
    final endpoint = _getDetailEndpoint(serviceType, id);
    final response = await _apiService.get(endpoint);
    return response as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // 🔍 AVAILABILITY (RESTORED)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> checkAvailability({
    required int id,
    required String serviceType,
    required String start,
    required String end,
    int adults = 1,
    int children = 0,
  }) async {
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
  }

  // ---------------------------------------------------------------------------
  // 📍 LOCATIONS (RESTORED)
  // ---------------------------------------------------------------------------

  Future<List<LocationModel>> getLocations({String? serviceName}) async {
    final response = await _apiService.get(
      ApiConfig.locations,
      queryParameters:
          serviceName?.isNotEmpty == true ? {'service_name': serviceName} : null,
    );

    final data = response['data'] as List?;
    if (data == null) return [];

    return data.map((e) => LocationModel.fromJson(e)).toList();
  }

  // ---------------------------------------------------------------------------
  // 🔥 BOOKING (MOBILE SAFE – FINAL)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createBooking({
  required String objectModel,
  required int objectId,
  required String startDate,
  required String endDate,
  int adults = 1,
  int children = 0,

  // HOTEL
  Map<int, int>? items,

  // TOUR
  Map<String, int>? personTypes,
  List<Map<String, dynamic>>? extraPrice,
}) async {
  final Map<String, dynamic> payload = {
    'object_model': objectModel,
    'object_id': objectId,
    'start_date': startDate,
    'end_date': endDate,
    'adults': adults,
    'children': children,
  };

  // ---------------------------------------------------------------------------
  // HOTEL: expand items[roomId][number]
  // ---------------------------------------------------------------------------
  if (items != null && items.isNotEmpty) {
    items.forEach((roomId, qty) {
      if (qty > 0) {
        payload['items[$roomId][number]'] = qty;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // TOUR: person_types[index][name|number]
  // ---------------------------------------------------------------------------
  if (objectModel == 'tour') {
  int i = 0;

  if (personTypes != null && personTypes.isNotEmpty) {
    personTypes.forEach((name, qty) {
      if (qty > 0) {
        payload['person_types[$i][name]'] = name;
        payload['person_types[$i][number]'] = qty;
        i++;
      }
    });
  }

  // 🔥 SAFETY: backend REQUIRES person_types
  if (i == 0) {
    payload['person_types[0][name]'] = 'Adult';
    payload['person_types[0][number]'] = 1;
  }
}

  // ---------------------------------------------------------------------------
  // TOUR: extra_price[index][name|number]
  // ---------------------------------------------------------------------------
  if (extraPrice != null && extraPrice.isNotEmpty) {
    int i = 0;
    for (final e in extraPrice) {
      if ((e['number'] ?? 0) > 0) {
        payload['extra_price[$i][name]'] = e['name'];
        payload['extra_price[$i][number]'] = e['number'];
        i++;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SAFETY: Laravel requires items[] even for tour
  // ---------------------------------------------------------------------------
  if (objectModel == 'tour' && !payload.keys.any((k) => k.startsWith('items['))) {
    payload['items[dummy][number]'] = 1;
  }

  return _apiService.post(
    '/booking/create',
    body: payload,
    isFormData: true, // 🔑 REQUIRED
  );
}



  // ---------------------------------------------------------------------------
  // 💳 CHECKOUT
  // ---------------------------------------------------------------------------

  Future<dynamic> doCheckout(String bookingCode) async {
    return await _apiService.get('booking/$bookingCode/checkout');
  }

  // ---------------------------------------------------------------------------
  // 🔎 SEARCH
  // ---------------------------------------------------------------------------

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
    final response =
        await _apiService.get(endpoint, queryParameters: queryParams);

    return SearchResponse.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // ⭐ REVIEWS
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getReviews({
    required int serviceId,
    required String serviceType,
  }) async {
    final response = await _apiService.get(
      'review',
      queryParameters: {
        'service_id': serviceId,
        'service_type': serviceType,
      },
    );

    if (response is Map && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // HELPERS
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
      default:
        throw Exception('Availability not supported for $serviceType');
    }
  }
}
