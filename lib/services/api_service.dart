import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../configs/api_config.dart';

class ApiService {
  static ApiService? _instance;

  ApiService._internal();

  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // URL NORMALIZATION (🔥 THIS IS THE FIX)
  // ---------------------------------------------------------------------------

  String _buildUrl(String endpoint) {
    final base = ApiConfig.baseUrl;

    if (base.endsWith('/') && endpoint.startsWith('/')) {
      return base + endpoint.substring(1);
    }
    if (!base.endsWith('/') && !endpoint.startsWith('/')) {
      return '$base/$endpoint';
    }
    return base + endpoint;
  }

  // ---------------------------------------------------------------------------
  // TOKEN
  // ---------------------------------------------------------------------------

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  // ---------------------------------------------------------------------------
  // GET
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      String url = _buildUrl(endpoint);

      if (queryParameters != null && queryParameters.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        )).query;
        url = '$url?$queryString';
      }

      print('GET → $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: ApiConfig.getHeaders(token: token),
          )
          .timeout(const Duration(milliseconds: ApiConfig.connectTimeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // POST
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    bool isFormData = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = _buildUrl(endpoint);
      http.Response response;

      if (isFormData) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded';

        final encodedBody = body?.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');

        print('POST → $url');
        print('Body → $encodedBody');

        response = await http
            .post(Uri.parse(url), headers: headers, body: encodedBody)
            .timeout(const Duration(milliseconds: ApiConfig.connectTimeout));
      } else {
        headers['Content-Type'] = 'application/json';

        response = await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(milliseconds: ApiConfig.connectTimeout));
      }

      return _handleResponse(response);
    } catch (e) {
      print('POST Error: $e');
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // PUT
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final response = await http
          .put(
            Uri.parse(_buildUrl(endpoint)),
            headers: ApiConfig.getHeaders(token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(milliseconds: ApiConfig.connectTimeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final response = await http
          .delete(
            Uri.parse(_buildUrl(endpoint)),
            headers: ApiConfig.getHeaders(token: token),
          )
          .timeout(const Duration(milliseconds: ApiConfig.connectTimeout));

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // RESPONSE HANDLING
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    print('Status Code: $statusCode');
    print('Response Body: ${response.body}');

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return {'status': true};
      }
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: statusCode,
        message: _getErrorMessage(response),
      );
    }
  }

  String _getErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ??
          body['error'] ??
          'Error ${response.statusCode}';
    } catch (_) {
      return 'Error ${response.statusCode}: ${response.body}';
    }
  }

  String _handleError(dynamic error) {
    print('Handling error: $error');

    if (error is ApiException) return error.message;

    if (error.toString().contains('SocketException')) {
      return 'No internet connection';
    }

    if (error.toString().contains('TimeoutException')) {
      return 'Connection timeout';
    }

    return 'Network error';
  }
}

// -----------------------------------------------------------------------------
// API EXCEPTION
// -----------------------------------------------------------------------------

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
