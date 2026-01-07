// lib/providers/locale_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = Locale('en');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  // Supported locales
  static List<Locale> supportedLocales = [
    Locale('en'), // English (default)
    Locale('vi'), // Vietnamese
    Locale('fr'), // French
    Locale('zh'), // Chinese
    Locale('ar'), // Arabic (RTL)
  ];

  // Language names
  static Map<String, String> languageNames = {
    'en': 'English',
    'vi': 'Tiếng Việt',
    'fr': 'Français',
    'zh': '中文',
    'ar': 'العربية',
  };

  // Language flags/icons
  static Map<String, String> languageFlags = {
    'en': '🇬🇧',
    'vi': '🇻🇳',
    'fr': '🇫🇷',
    'zh': '🇨🇳',
    'ar': '🇸🇦',
  };

  // Check if language is RTL
  static bool isRTL(Locale locale) {
    return locale.languageCode == 'ar';
  }

  // Load saved locale
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode);
    ApiConfig.currentLanguage = languageCode;
    notifyListeners();
  }

  // Set locale
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;

    _locale = locale;
    notifyListeners();

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  // Clear locale (reset to default)
  Future<void> clearLocale() async {
    _locale = Locale('en');
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
  }
}