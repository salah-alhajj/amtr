import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:localization/src/localization_service.dart';

/// مساعد إدارة الترجمات للوصول السريع بدون BuildContext
class LocalizationHelper {
  static Map<String, String>? _localizedStrings;
  static String _currentLanguage = 'ar';

  static String get currentLanguage => _currentLanguage;

  /// تحميل ملف الترجمة وتحديث الذاكرة
  static Future<void> load(String languageCode) async {
    if (_localizedStrings != null &&
        _localizedStrings!.isNotEmpty &&
        _currentLanguage == languageCode) {
      return;
    }
    _currentLanguage = languageCode;
    try {
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('i18n/$languageCode.json');
      } catch (_) {
        jsonString = await rootBundle.loadString('assets/i18n/$languageCode.json');
      }
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final Map<String, String> mapped = {};
      jsonMap.forEach((key, value) {
        mapped[key] = value.toString();
      });
      _localizedStrings = mapped;
      LocalizationService.instance.changeLanguageFromMap(Locale(languageCode), mapped);
    } catch (_) {
      if (_localizedStrings != null &&
          _localizedStrings!.isNotEmpty &&
          _currentLanguage == languageCode) {
        return;
      }
      // الرجوع للغة العربية كخيار بديل آمن
      if (languageCode != 'ar') {
        await load('ar');
      } else {
        _localizedStrings = {};
      }
    }
  }

  /// ترجمة المفتاح مع استبدال المعاملات
  static String translate(String key, {Map<String, String>? params}) {
    String translation = _localizedStrings?[key] ?? key;

    if (params != null) {
      params.forEach((paramKey, paramValue) {
        translation = translation.replaceAll('{$paramKey}', paramValue);
        translation = translation.replaceAll('%s{$paramKey}', paramValue);
      });
    }

    return translation;
  }

  static Map<String, String>? get localizedStrings => _localizedStrings;

  /// تعيين الخريطة مباشرة
  static void setStrings(Map<String, String> strings, String languageCode) {
    if (strings.isEmpty) return;
    _localizedStrings = strings;
    _currentLanguage = languageCode;
    LocalizationService.instance.changeLanguageFromMap(Locale(languageCode), strings);
  }
}

