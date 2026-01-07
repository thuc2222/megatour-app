// lib/utils/context_extension.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension BuildContextExtension on BuildContext {
  // Biến tắt để gọi l10n cực nhanh
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  
  // Tiện thể làm luôn biến tắt cho Theme (dùng nhiều cũng rất tiện)
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
}