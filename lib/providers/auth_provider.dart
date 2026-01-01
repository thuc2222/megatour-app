import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  String? _token;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  String? get token => _token;

  // Initialize - check if user is already logged in
  Future<void> initialize() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        // --- FIX: Retrieve the token from storage during initialization ---
        _token = await _authService.getToken(); 
        _user = await _authService.getCurrentUser();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
        _token = null;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.login(
        email: email,
        password: password,
      );

      if (response.status) {
        // --- FIX: Capture the token from the login response ---
        // Assuming your response object or AuthService saves/returns the token
        _token = await _authService.getToken(); 
        
        _user = await _authService.getCurrentUser();
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = response.message ?? 'Login failed';
        _token = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _token = null;
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    bool acceptTerms = true,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        acceptTerms: acceptTerms,
      );

      if (response.status) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = response.message ?? 'Registration failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Update profile
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
      _errorMessage = null;

      final success = await _authService.updateProfile(
        businessName: businessName,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        birthday: birthday,
        bio: bio,
        address: address,
        address2: address2,
        city: city,
        country: country,
        zipCode: zipCode,
        avatarId: avatarId,
      );

      if (success) {
        _user = await _authService.getCurrentUser();
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _errorMessage = null;

      final success = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!success) {
        _errorMessage = 'Failed to change password';
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _authService.logout();
      _user = null;
      _token = null; // --- FIX: Clear token on logout ---
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUser() async {
    try {
      _user = await _authService.getCurrentUser();
      _token = await _authService.getToken(); // Keep token in sync
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}