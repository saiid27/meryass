import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';

extension AppLocale on BuildContext {
  /// Translate a key to the currently selected language.
  /// Falls back to French if the key is missing.
  String tr(String key) {
    final lang = Localizations.localeOf(this).languageCode;
    return appStrings[key]?[lang] ?? appStrings[key]?['fr'] ?? key;
  }

  /// Current locale from LocaleProvider.
  Locale get locale => Localizations.localeOf(this);

  bool get isArabic => locale.languageCode == 'ar';
}

/// Small language-toggle button — drop it anywhere in an AppBar.actions list.
class LangToggleButton extends StatelessWidget {
  const LangToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final activeLanguage = localeProvider.locale.languageCode;

    return Container(
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: 'FR',
              selected: activeLanguage == 'fr',
              onTap: () => localeProvider.setLocale(const Locale('fr')),
            ),
            _LanguageOption(
              label: 'AR',
              selected: activeLanguage == 'ar',
              onTap: () => localeProvider.setLocale(const Locale('ar')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
