import '../providers/app_config_provider.dart';

String formatCurrency(double amount, AppCurrency currency) {
  final value = amount * currency.rate;

  String text = currency.noDecimal
      ? value.round().toString()
      : value.toStringAsFixed(2);

  final parts = text.split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => currency.thousand,
  );

  final formatted =
      parts.length > 1 ? parts.join(currency.decimal) : parts[0];

  return currency.format == 'left'
      ? '${currency.symbol}$formatted'
      : '$formatted${currency.symbol}';
}
