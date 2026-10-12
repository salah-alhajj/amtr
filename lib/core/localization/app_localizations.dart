import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:localization/src/localization_service.dart';
import 'localization_helper.dart';

/// يدير تحميل النصوص المترجمة والوصول إليها عبر السياق أو المفاتيح
/// يدعم العربية (الأساسية) والإنجليزية مع fallback آمن يمنع أي توقف مفاجئ
class AppLocalizations {
  final Locale locale;
  Map<String, String> _localizedStrings = {};

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations._fallback();
  }

  AppLocalizations._fallback()
      : locale = const Locale('ar'),
        _localizedStrings = const {};

  /// تحميل ملفات الترجمة للغة المطلوبة
  Future<bool> load() async {
    final lc = locale.languageCode;
    final cc = locale.countryCode;

    final Map<String, String> merged = {};

    // 1. تحميل الأساس الافتراضي أولاً من مجلد الترجمات الموحد (العربية كمرجع أساسي ثم الإنجليزية)
    final fallbackCandidates = <String>[
      'i18n/ar.json',
      'assets/i18n/ar.json',
      'i18n/en.json',
      'assets/i18n/en.json',
    ];

    for (final path in fallbackCandidates) {
      try {
        final jsonString = await rootBundle.loadString(path);
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        jsonMap.forEach((key, value) {
          merged[key] = value.toString();
        });
        break;
      } catch (_) {
        // الاستمرار للملف التالي
      }
    }

    // 2. إذا كانت اللغة المطلوبة مختلفة، تحميلها للكتابة فوق الأساس
    final targetCandidates = <String>[
      if (cc != null && cc.isNotEmpty) 'i18n/${lc}_$cc.json',
      if (cc != null && cc.isNotEmpty) 'assets/i18n/${lc}_$cc.json',
      'i18n/$lc.json',
      'assets/i18n/$lc.json',
    ];

    for (final path in targetCandidates) {
      try {
        final jsonString = await rootBundle.loadString(path);
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        jsonMap.forEach((key, value) {
          merged[key] = value.toString();
        });
        break;
      } catch (_) {
        // المحاولة مع المسار التالي
      }
    }

    if (merged.isNotEmpty) {
      _localizedStrings = merged;
      // مزامنة مع مكتبة localization الداخلية لدعم .i18n()
      LocalizationService.instance.changeLanguageFromMap(locale, merged);
      return true;
    }

    if (LocalizationHelper.localizedStrings != null &&
        LocalizationHelper.localizedStrings!.isNotEmpty &&
        LocalizationHelper.currentLanguage == lc) {
      _localizedStrings = LocalizationHelper.localizedStrings!;
      LocalizationService.instance.changeLanguageFromMap(locale, _localizedStrings);
      return true;
    }

    _localizedStrings = const {};
    return false;
  }

  /// ترجمة المفتاح مع استبدال المعاملات الاختيارية
  String translate(String key, {Map<String, String>? params}) {
    String translation = _localizedStrings[key] ?? key;

    if (params != null) {
      params.forEach((paramKey, paramValue) {
        translation = translation.replaceAll('{$paramKey}', paramValue);
        translation = translation.replaceAll('%s{$paramKey}', paramValue);
      });
    }

    return translation;
  }

  Map<String, String> get localizedStrings => _localizedStrings;
}

/// Delegator الخاص بـ Flutter Localizations
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  @override
  bool isSupported(Locale locale) {
    return supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
