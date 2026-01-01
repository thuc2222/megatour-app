// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static ApiService? _instance;
  
  ApiService._internal();
  
  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }
  
  // Get stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  
  // Save token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }
  
  // Remove token
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }
  
  // GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      
      String url = '${ApiConfig.baseUrl}$endpoint';
      
      if (queryParameters != null && queryParameters.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        )).query;
        url = '$url?$queryString';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.getHeaders(token: token),
      ).timeout(
        const Duration(milliseconds: ApiConfig.connectTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // POST request
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
      
      http.Response response;
      
      if (isFormData) {
        // For form-urlencoded data (like login)
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
        
        final encodedBody = body?.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        
        print('POST URL: ${ApiConfig.baseUrl}$endpoint');
        print('Headers: $headers');
        print('Body: $encodedBody');
        
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
          body: encodedBody,
        ).timeout(
          const Duration(milliseconds: ApiConfig.connectTimeout),
        );
      } else {
        // For JSON data
        headers['Content-Type'] = 'application/json';
        
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(
          const Duration(milliseconds: ApiConfig.connectTimeout),
        );
      }
      
      return _handleResponse(response);
    } catch (e) {
      print('POST Error: $e');
      throw _handleError(e);
    }
  }
  
  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.getHeaders(token: token),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(
        const Duration(milliseconds: ApiConfig.connectTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;
      
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.getHeaders(token: token),
      ).timeout(
        const Duration(milliseconds: ApiConfig.connectTimeout),
      );
      
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // Handle response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    // Debug: Print response
    print('Status Code: $statusCode');
    print('Response Body: ${response.body}');
    
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return {'status': true};
      }
      try {
        final decoded = jsonDecode(response.body);
        print('Decoded Response: $decoded');
        return decoded;
      } catch (e) {
        print('JSON Decode Error: $e');
        throw ApiException(
          statusCode: statusCode,
          message: 'Invalid JSON response',
        );
      }
    } else {
      throw ApiException(
        statusCode: statusCode,
        message: _getErrorMessage(response),
      );
    }
  }
  
  // Get error message from response
  String _getErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      
      // Check different error message formats
      if (body['message'] != null) {
        return body['message'];
      }
      if (body['error'] != null) {
        return body['error'];
      }
      if (body['errors'] != null) {
        if (body['errors'] is Map) {
          // Laravel validation errors format
          final errors = body['errors'] as Map;
          return errors.values.first[0] ?? 'Validation error';
        }
        return body['errors'].toString();
      }
      
      return 'Error: ${response.statusCode}';
    } catch (e) {
      print('Error parsing error message: $e');
      return 'Error: ${response.statusCode} - ${response.body}';
    }
  }
  
  // Handle errors
  String _handleError(dynamic error) {
    print('Handling error: $error');
    
    if (error is ApiException) {
      return error.message;
    }
    
    if (error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    
    if (error.toString().contains('TimeoutException')) {
      return 'Connection timeout. Please try again.';
    }
    
    return 'Network error: ${error.toString()}';
  }
}

// Custom exception class
class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException({
    required this.statusCode,
    required this.message,
  });
  
  @override
  String toString() => message;
}