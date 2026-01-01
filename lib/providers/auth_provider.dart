import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  UserModel? user;
  String? token;

  bool isAuthenticated = false;
  bool isLoading = false;
  String? errorMessage;

  /// ================================
  /// APP INIT
  /// ================================
  Future<void> initialize() async {
  try {
    token = await _api.getToken();

    // No token = guest mode → OK
    if (token == null) return;

    // Try restoring user, but NEVER crash app
    await fetchMe();
  } catch (_) {
    // If token is invalid → clear it, stay guest
    await _api.removeToken();
    token = null;
    user = null;
    isAuthenticated = false;
  }
  }

  /// ================================
  /// LOGIN
  /// ================================
  Future<bool> login({
  required String email,
  required String password,
}) async {
  try {
    isLoading = true;
    notifyListeners();

    final res = await _api.post(
      'auth/login',
      body: {
        'email': email,
        'password': password,
        'device_name': 'flutter_app',
      },
      isFormData: true,
    );

    if (res['status'] != 1) {
      errorMessage = 'Login failed';
      return false;
    }

    token = res['access_token']; // ✅ FIX
    await _api.saveToken(token!);

    user = UserModel.fromJson(res['user']);
    isAuthenticated = true;
    return true;
  } catch (e) {
    errorMessage = e.toString();
    return false;
  } finally {
    isLoading = false;
    notifyListeners();
  }
}

  /// ================================
  /// REGISTER
  /// ================================
  Future<bool> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    bool? acceptTerms,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final res = await _api.post(
        'auth/register',
        body: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'device_name': 'flutter_app',
          'accept_terms': acceptTerms == true ? 1 : 0,
        },
        isFormData: true,
      );

      if (res['status'] != 1) {
        errorMessage = res['errors']?.values.first.first;
        return false;
      }

      token = res['token'];
      await _api.saveToken(token!);

      user = UserModel.fromJson(res['user']);
      isAuthenticated = true;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// ================================
  /// CURRENT USER
  /// ================================
  Future<void> fetchMe() async {
    final res = await _api.get(
      'auth/me',
      requiresAuth: true,
    );

    user = UserModel.fromJson(res['data']);
    isAuthenticated = true;
    notifyListeners();
  }

  /// ================================
  /// UPDATE PROFILE
  /// ================================
  Future<bool> updateProfile(Map<String, dynamic> payload) async {
    try {
      isLoading = true;
      notifyListeners();

      final res = await _api.post(
        'auth/me',
        body: payload,
        requiresAuth: true,
      );

      user = UserModel.fromJson(res['data']);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// ================================
  /// CHANGE PASSWORD
  /// ================================
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      await _api.post(
        'auth/change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// ================================
  /// LOGOUT
  /// ================================
  Future<void> logout() async {
    try {
      await _api.post(
        'auth/logout',
        requiresAuth: true,
      );
    } catch (_) {}

    await _api.removeToken();
    token = null;
    user = null;
    isAuthenticated = false;
    notifyListeners();
  }
}
