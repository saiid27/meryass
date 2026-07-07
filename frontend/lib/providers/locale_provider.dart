import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _key = 'locale_lang';

  LocaleProvider({Locale initialLocale = const Locale('fr')})
    : _locale = initialLocale;

  Locale _locale;

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  static Future<Locale> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_key) ?? 'fr';
    return Locale(lang == 'ar' ? 'ar' : 'fr');
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  Future<void> toggle() async {
    await setLocale(isArabic ? const Locale('fr') : const Locale('ar'));
  }
}
