import 'package:flutter/material.dart';

/// نموذج بيانات اللغات المدعومة في التطبيق
class AppLanguage {
  final String code;
  final String nativeName;
  final String translationKey;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.translationKey,
  });

  /// اللغات الخمس المعتمدة رسمياً:
  /// - العربية: العلم اليمني حصراً
  /// - الإنجليزية: علم الولايات المتحدة
  /// - التركية: علم تركيا
  /// - الفرنسية: علم فرنسا
  /// - الإسبانية: علم إسبانيا
  static const List<AppLanguage> supported = [
    AppLanguage(
      code: 'ar',
      nativeName: 'العربية',
      translationKey: 'language_arabic_rtl',
    ),
    AppLanguage(
      code: 'en',
      nativeName: 'English',
      translationKey: 'language_english_ltr',
    ),
    AppLanguage(
      code: 'tr',
      nativeName: 'Türkçe',
      translationKey: 'language_turkish',
    ),
    AppLanguage(
      code: 'fr',
      nativeName: 'Français',
      translationKey: 'language_french',
    ),
    AppLanguage(
      code: 'es',
      nativeName: 'Español',
      translationKey: 'language_spanish',
    ),
  ];

  static AppLanguage fromCode(String code) {
    return supported.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => supported.first,
    );
  }

  Locale get locale => Locale(code);
}
