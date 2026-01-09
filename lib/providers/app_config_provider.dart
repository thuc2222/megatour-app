import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:megatour_app/config/api_config.dart';

class AppCurrency {
  final String code;
  final String symbol;
  final String format;
  final String thousand;
  final String decimal;
  final bool noDecimal;
  final double rate;

  AppCurrency({
    required this.code,
    required this.symbol,
    required this.format,
    required this.thousand,
    required this.decimal,
    required this.noDecimal,
    required this.rate,
  });

  factory AppCurrency.fromJson(Map<String, dynamic> json) {
    return AppCurrency(
      code: json['currency_main'] ?? '',
      symbol: json['symbol'] ?? '',
      format: json['currency_format'] ?? 'left',
      thousand: json['currency_thousand'] ?? ',',
      decimal: json['currency_decimal'] ?? '.',
      noDecimal: json['currency_no_decimal'] == '1',
      rate: (json['rate'] as num?)?.toDouble() ?? 1,
    );
  }
}

class AppConfigProvider extends ChangeNotifier {
  AppCurrency? currency;
  bool loaded = false;

  Future<void> load() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}configs'),
      );

      final json = jsonDecode(res.body);
      final List currencies = json['currency'] ?? [];

      final main = currencies.firstWhere(
        (c) => c['is_main'] == 1,
        orElse: () => null,
      );

      if (main != null) {
        currency = AppCurrency.fromJson(main);
      }

      loaded = true;
      notifyListeners();
    } catch (_) {
      loaded = true;
      notifyListeners();
    }
  }
}
