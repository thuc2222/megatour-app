// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class SettingsProvider extends ChangeNotifier {
  String _currentLanguage = 'en';
  String _currentCurrency = 'USD';
  bool _notificationsEnabled = true;
  
  // 🟢 Backend language data
  List<Map<String, dynamic>> _availableLanguages = [];
  Map<String, dynamic>? _appConfig;
  bool _configLoaded = false;

  // Getters
  String get currentLanguage => _currentLanguage;
  String get currentCurrency => _currentCurrency;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get configLoaded => _configLoaded;
  
  // 🟢 Get languages from backend
  List<Map<String, dynamic>> get availableLanguages => _availableLanguages;
  
  // Get language name
  String get currentLanguageName {
    if (_availableLanguages.isEmpty) return 'English';
    
    final lang = _availableLanguages.firstWhere(
      (l) => l['locale'] == _currentLanguage,
      orElse: () => {'name': 'English'},
    );
    return lang['name'] ?? 'English';
  }

  // Available currencies from backend or default
  final List<String> availableCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'VND',
    'JPY',
    'KRW',
    'CNY',
    'AUD',
    'CAD',
  ];

  /// ================================
  /// INITIALIZATION
  /// ================================
  Future<void> initialize() async {
    // 1. Load local preferences first
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'en';
    _currentCurrency = prefs.getString('currency') ?? 'USD';
    _notificationsEnabled = prefs.getBool('notifications') ?? true;
    
    // 2. Load backend config
    await loadBackendConfig();
    
    notifyListeners();
  }

  /// ================================
  /// LOAD BACKEND CONFIG
  /// ================================
  Future<void> loadBackendConfig() async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.configs}';
      final res = await http.get(
        Uri.parse(url),
        headers: ApiConfig.getHeaders(),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _appConfig = data;
        
        // Extract languages
        if (data['languages'] is List) {
          _availableLanguages = List<Map<String, dynamic>>.from(
            data['languages'].map((l) => Map<String, dynamic>.from(l)),
          );
        }
        
        _configLoaded = true;
        debugPrint('✅ Backend config loaded: ${_availableLanguages.length} languages');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load backend config: $e');
      // Fallback to default languages
      _availableLanguages = [
        {'locale': 'en', 'name': 'English'},
        {'locale': 'vi', 'name': 'Tiếng Việt'},
        {'locale': 'fr', 'name': 'Français'},
        {'locale': 'ar', 'name': 'Saudi Arabia'},
        {'locale': 'zh', 'name': '中文'},
      ];
      _configLoaded = true;
    }
    notifyListeners();
  }

  /// ================================
  /// LANGUAGE CHANGE
  /// ================================
  Future<void> setLanguage(String languageCode) async {
    // Validate language exists in backend
    final langExists = _availableLanguages.any(
      (l) => l['locale'] == languageCode,
    );
    
    if (!langExists) {
      debugPrint('⚠️ Language $languageCode not supported by backend');
      return;
    }
    
    _currentLanguage = languageCode;
    
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    
    debugPrint('✅ Language changed to: $languageCode');
    notifyListeners();
  }

  /// ================================
  /// CURRENCY
  /// ================================
  Future<void> setCurrency(String currency) async {
    if (!availableCurrencies.contains(currency)) return;
    
    _currentCurrency = currency;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    
    notifyListeners();
  }

  /// ================================
  /// NOTIFICATIONS
  /// ================================
  Future<void> setNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', enabled);
    
    notifyListeners();
  }

  /// ================================
  /// CURRENCY FORMATTING
  /// ================================
  String formatPrice(double price) {
    switch (_currentCurrency) {
      case 'USD':
        return '\$$price';
      case 'EUR':
        return '€$price';
      case 'GBP':
        return '£$price';
      case 'VND':
        return '${(price * 24000).toStringAsFixed(0)}₫';
      case 'JPY':
        return '¥${(price * 150).toStringAsFixed(0)}';
      case 'KRW':
        return '₩${(price * 1300).toStringAsFixed(0)}';
      case 'CNY':
        return '¥${(price * 7).toStringAsFixed(0)}';
      case 'AUD':
        return 'A\$${(price * 1.5).toStringAsFixed(2)}';
      case 'CAD':
        return 'C\$${(price * 1.35).toStringAsFixed(2)}';
      default:
        return '\$$price';
    }
  }

  /// ================================
  /// GET LANGUAGE FLAG EMOJI
  /// ================================
  String getLanguageFlag(String locale) {
    switch (locale) {
      case 'en':
        return '🇬🇧';
      case 'vi':
        return '🇻🇳';
      case 'fr':
        return '🇫🇷';
      case 'ar':
        return '🇸🇦';
      case 'zh':
        return '🇨🇳';
      default:
        return '🌐';
    }
  }
}