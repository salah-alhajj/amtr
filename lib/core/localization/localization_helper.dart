import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:localization/src/localization_service.dart';
import '../services/preferences_service.dart';
import 'arabic_dialect.dart';

/// مساعد إدارة الترجمات للوصول السريع بدون BuildContext
class LocalizationHelper {
  static Map<String, String>? _localizedStrings;
  static String _currentLanguage = 'ar';
  static String _currentArabicDialect = ArabicDialect.standardId;

  static String get currentLanguage => _currentLanguage;
  static String get currentArabicDialect => _currentArabicDialect;

  /// تحميل ملف الترجمة وتحديث الذاكرة (مع دمج اللهجة العربية المختارة عند التفعيل)
  static Future<void> load(
    String languageCode, {
    String? arabicDialect,
  }) async {
    final effectiveDialect = languageCode == 'ar'
        ? ArabicDialect.fromId(
            arabicDialect ?? PreferencesService.instance.getArabicDialect(),
          ).id
        : ArabicDialect.standardId;

    if (_localizedStrings != null &&
        _localizedStrings!.isNotEmpty &&
        _currentLanguage == languageCode &&
        _currentArabicDialect == effectiveDialect) {
      return;
    }

    _currentLanguage = languageCode;
    _currentArabicDialect = effectiveDialect;
    try {
      final jsonString = await rootBundle.loadString('i18n/$languageCode.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final Map<String, String> mapped = {};
      jsonMap.forEach((key, value) {
        mapped[key] = value.toString();
      });

      if (languageCode == 'ar' &&
          effectiveDialect != ArabicDialect.standardId) {
        final dialectObj = ArabicDialect.fromId(effectiveDialect);
        if (dialectObj.assetPath != null) {
          try {
            final dialectStr = await rootBundle.loadString(
              dialectObj.assetPath!,
            );
            final Map<String, dynamic> dialectMap = json.decode(dialectStr);
            dialectMap.forEach((key, value) {
              mapped[key] = value.toString();
            });
          } catch (_) {
            // الاحتفاظ بالترجمة العربية الأساسية عند تعذر تحميل ملف اللهجة
          }
        }
      }

      _localizedStrings = mapped;
      LocalizationService.instance.changeLanguageFromMap(
        Locale(languageCode),
        mapped,
      );
    } catch (_) {
      if (_localizedStrings != null &&
          _localizedStrings!.isNotEmpty &&
          _currentLanguage == languageCode &&
          _currentArabicDialect == effectiveDialect) {
        return;
      }
      // الرجوع للغة العربية كخيار بديل آمن
      if (languageCode != 'ar') {
        await load('ar', arabicDialect: arabicDialect);
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
  static void setStrings(
    Map<String, String> strings,
    String languageCode, {
    String? arabicDialect,
  }) {
    if (strings.isEmpty) return;
    _localizedStrings = strings;
    _currentLanguage = languageCode;
    if (arabicDialect != null) {
      _currentArabicDialect = ArabicDialect.fromId(arabicDialect).id;
    } else if (languageCode != 'ar') {
      _currentArabicDialect = ArabicDialect.standardId;
    }
    LocalizationService.instance.changeLanguageFromMap(
      Locale(languageCode),
      strings,
    );
  }
}

