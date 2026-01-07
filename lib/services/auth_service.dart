// lib/services/auth_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // --- NEW METHOD ADDED HERE ---
  /// Exposes the token from ApiService to the AuthProvider
  Future<String?> getToken() async {
    return await _apiService.getToken();
  }

  // Login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting login with email: $email');
      
      // Get device info for device_name
      final deviceName = await _getDeviceName();
      print('Device name: $deviceName');
      
      // API expects form-urlencoded data with device_name
      final response = await _apiService.post(
        ApiConfig.login,
        body: {
          'email': email,
          'password': password,
          'device_name': deviceName,
        },
        isFormData: true,
      );

      print('Login response: $response');

      final authResponse = AuthResponse.fromJson(response);

      // Save token if login successful
      if (authResponse.status && authResponse.accessToken != null) {
        await _apiService.saveToken(authResponse.accessToken!);
        print('Token saved successfully');
      }

      return authResponse;
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Get device name for login
  Future<String> _getDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
      }
      
      return deviceId;
    } catch (e) {
      return 'flutter_mobile_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Register
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    bool acceptTerms = true,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConfig.register,
        body: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'term': acceptTerms ? 1 : 0,
        },
      );

      return AuthResponse.fromJson(response);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Get current user info
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _apiService.get(
        ApiConfig.me,
        requiresAuth: true,
      );

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user info: ${e.toString()}');
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? businessName,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? birthday,
    String? bio,
    String? address,
    String? address2,
    String? city,
    String? country,
    String? zipCode,
    int? avatarId,
  }) async {
    try {
      final body = <String, dynamic>{};
      
      if (businessName != null) body['business_name'] = businessName;
      if (email != null) body['email'] = email;
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (phone != null) body['phone'] = phone;
      if (birthday != null) body['birthday'] = birthday;
      if (bio != null) body['bio'] = bio;
      if (address != null) body['address'] = address;
      if (address2 != null) body['address2'] = address2;
      if (city != null) body['city'] = city;
      if (country != null) body['country'] = country;
      if (zipCode != null) body['zip_code'] = zipCode;
      if (avatarId != null) body['avatar_id'] = avatarId;

      final response = await _apiService.post(
        ApiConfig.updateProfile,
        body: body,
        requiresAuth: true,
      );

      return response['status'] == true || response['status'] == 1;
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConfig.changePassword,
        body: {
          'current-password': currentPassword,
          'new-password': newPassword,
        },
        requiresAuth: true,
      );

      return response['status'] == true || response['status'] == 1;
    } catch (e) {
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }

  // Logout
  Future<bool> logout() async {
    try {
      await _apiService.post(
        ApiConfig.logout,
        requiresAuth: true,
      );

      // Remove token
      await _apiService.removeToken();

      return true;
    } catch (e) {
      // Even if API call fails, remove token locally
      await _apiService.removeToken();
      return true;
    }
  }

  // Refresh token
  Future<AuthResponse> refreshToken() async {
    try {
      final response = await _apiService.post(
        ApiConfig.refreshToken,
        requiresAuth: true,
      );

      final authResponse = AuthResponse.fromJson(response);

      // Save new token
      if (authResponse.status && authResponse.accessToken != null) {
        await _apiService.saveToken(authResponse.accessToken!);
      }

      return authResponse;
    } catch (e) {
      throw Exception('Failed to refresh token: ${e.toString()}');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _apiService.getToken();
    return token != null && token.isNotEmpty;
  }
}