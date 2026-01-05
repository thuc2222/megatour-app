// lib/providers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _currentLanguage = 'en';
  String _currentCurrency = 'USD';
  bool _notificationsEnabled = true;

  // Getters
  String get currentLanguage => _currentLanguage;
  String get currentCurrency => _currentCurrency;
  bool get notificationsEnabled => _notificationsEnabled;

  // Available options
  final Map<String, String> availableLanguages = {
    'en': 'English',
    'vi': 'Tiếng Việt',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
  };

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

  // Get language name
  String get currentLanguageName =>
      availableLanguages[_currentLanguage] ?? 'English';

  /// ================================
  /// INITIALIZATION
  /// ================================
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _currentLanguage = prefs.getString('language') ?? 'en';
    _currentCurrency = prefs.getString('currency') ?? 'USD';
    _notificationsEnabled = prefs.getBool('notifications') ?? true;
    
    notifyListeners();
  }

  /// ================================
  /// LANGUAGE
  /// ================================
  Future<void> setLanguage(String languageCode) async {
    if (!availableLanguages.containsKey(languageCode)) return;
    
    _currentLanguage = languageCode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    
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
  /// CURRENCY CONVERSION
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
  /// RESET SETTINGS
  /// ================================
  Future<void> resetSettings() async {
    _currentLanguage = 'en';
    _currentCurrency = 'USD';
    _notificationsEnabled = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    notifyListeners();
  }
}