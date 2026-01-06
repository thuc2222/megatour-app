// lib/widgets/language_selector.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/locale_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // final localeProvider = context.watch<LocaleProvider>();
    // final l10n = AppLocalizations.of(context)!;

    // The extra return statement has been removed.
    // Now, this ListTile will be built and returned correctly.
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.blue),
      title: Text(l10n.language),
      subtitle: Text(
        LocaleProvider.languageNames[localeProvider.locale.languageCode] ?? 'English',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: LocaleProvider.supportedLocales.map((locale) {
              final isSelected = localeProvider.locale == locale;
              final flag = LocaleProvider.languageFlags[locale.languageCode] ?? '';
              final name = LocaleProvider.languageNames[locale.languageCode] ?? '';
              return ListTile(
                leading: Text(
                  flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(name),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  localeProvider.setLocale(locale);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

// Alternative: Bottom Sheet Style
class LanguageSelectorBottomSheet extends StatelessWidget {
  const LanguageSelectorBottomSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LanguageSelectorBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.selectLanguage,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...LocaleProvider.supportedLocales.map((locale) {
            final isSelected = localeProvider.locale == locale;
            final flag = LocaleProvider.languageFlags[locale.languageCode] ?? '';
            final name = LocaleProvider.languageNames[locale.languageCode] ?? '';

            return ListTile(
              leading: Text(
                flag,
                style: const TextStyle(fontSize: 28),
              ),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : null,
              onTap: () {
                localeProvider.setLocale(locale);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}