import '../configs/api_config.dart';
import '../models/service_models.dart';
import 'api_service.dart';

class ServiceApi {
  final ApiService _apiService = ApiService();

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

  Future<Map<String, dynamic>> createBooking({
  required String objectModel,
  required int objectId,
  required String startDate,
  required String endDate,
  int adults = 1,
  int children = 0,
  Map<int, int>? items,
  Map<String, int>? personTypes,
  List<Map<String, dynamic>>? extraPrice,
}) async {
  final Map<String, dynamic> payload = {
    'object_model': objectModel,
    'object_id': objectId.toString(),
    'start_date': startDate,
    'end_date': endDate,
    'adults': adults.toString(),
    'children': children.toString(),
  };

  if (items != null && items.isNotEmpty) {
    items.forEach((roomId, qty) {
      if (qty > 0) {
        payload['items[$roomId][number]'] = qty.toString();
      }
    });
  }

  if (objectModel == 'tour') {
    int i = 0;
    if (personTypes != null && personTypes.isNotEmpty) {
      personTypes.forEach((name, qty) {
        if (qty > 0) {
          payload['person_types[$i][name]'] = name;
          payload['person_types[$i][number]'] = qty.toString();
          i++;
        }
      });
    }
    if (i == 0) {
      payload['person_types[0][name]'] = 'Adult';
      payload['person_types[0][number]'] = '1';
    }
  }

  if (extraPrice != null && extraPrice.isNotEmpty) {
    int i = 0;
    for (final e in extraPrice) {
      if ((e['number'] ?? 0) > 0) {
        payload['extra_price[$i][name]'] = e['name'];
        payload['extra_price[$i][number]'] = e['number'].toString();
        i++;
      }
    }
  }

  return _apiService.post(
    '/booking/create',
    body: payload,
    isFormData: true,
  );
}

  Future<dynamic> doCheckout(String bookingCode) async {
    return await _apiService.get('booking/$bookingCode/checkout');
  }

  Future<Map<String, dynamic>> confirmBooking({
    required String bookingCode,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String paymentMethod,
  }) async {
    return _apiService.post(
      '/booking/mobile-confirm',
      body: {
        'booking_code': bookingCode,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'payment_method': paymentMethod,
      },
      isFormData: true,
    );
  }

  Future<SearchResponse> searchServices({
    required String serviceType,
    String? serviceName,
    String? locationName,
    String? orderBy,
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': page.toString(), 'limit': '9'};
    if (serviceName != null && serviceName.isNotEmpty) {
      queryParams['s'] = serviceName;
    }
    if (locationName != null && locationName.isNotEmpty) {
      queryParams['location_name'] = locationName;
    }
    if (orderBy != null && orderBy.isNotEmpty) {
      queryParams['orderby'] = orderBy;
    }

    final uri = Uri.parse('/$serviceType/search').replace(queryParameters: queryParams);
    final Map<String, dynamic> response = await _apiService.get(uri.toString());
    return SearchResponse.fromJson(response);
  }

  Future<List<dynamic>> getReviews({
    required int serviceId,
    required String serviceType,
  }) async {
    final response = await _apiService.get(
      'review',
      queryParameters: {'service_id': serviceId, 'service_type': serviceType},
    );
    if (response is Map && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  String _getDetailEndpoint(String serviceType, int id) {
    switch (serviceType.toLowerCase()) {
      case 'hotel': return ApiConfig.hotelDetail(id);
      case 'tour': return ApiConfig.tourDetail(id);
      case 'space': return ApiConfig.spaceDetail(id);
      case 'car': return ApiConfig.carDetail(id);
      default: throw Exception('Invalid service type: $serviceType');
    }
  }

  String _getAvailabilityEndpoint(String serviceType, int id) {
    switch (serviceType.toLowerCase()) {
      case 'hotel': return ApiConfig.hotelAvailability(id);
      case 'tour': return ApiConfig.tourAvailability(id);
      case 'space': return ApiConfig.spaceAvailability(id);
      case 'car': return ApiConfig.carAvailability(id);
      default: throw Exception('Availability not supported for $serviceType');
    }
  }
}
