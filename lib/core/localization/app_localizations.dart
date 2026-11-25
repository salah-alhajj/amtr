import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:localization/src/localization_service.dart';
import 'arabic_dialect.dart';
import 'localization_helper.dart';

/// يدير تحميل النصوص المترجمة والوصول إليها عبر السياق أو المفاتيح
/// يدعم العربية (الأساسية + اللهجات الإقليمية كطبقة فوقها) واللغات الأخرى مع fallback آمن
class AppLocalizations {
  final Locale locale;
  final String arabicDialect;
  Map<String, String> _localizedStrings = {};

  AppLocalizations(
    this.locale, {
    this.arabicDialect = ArabicDialect.standardId,
  });

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations._fallback();
  }

  AppLocalizations._fallback()
      : locale = const Locale('ar'),
        arabicDialect = ArabicDialect.standardId,
        _localizedStrings = const {};

  /// تحميل ملفات الترجمة للغة المطلوبة
  Future<bool> load() async {
    final lc = locale.languageCode;
    final cc = locale.countryCode;

    final Map<String, String> merged = {};

    // 1. تحميل الأساس الافتراضي أولاً من مجلد الترجمات الموحد في جذر المشروع (العربية كمرجع أساسي ثم الإنجليزية)
    final fallbackCandidates = <String>[
      'i18n/ar.json',
      'i18n/en.json',
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
      'i18n/$lc.json',
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

    // 3. عند اختيار العربية مع لهجة بلدية محددة، تحميل ملف اللهجة كطبقة فوق i18n/ar.json
    if (lc == 'ar') {
      final dialect = ArabicDialect.fromId(arabicDialect);
      if (dialect.id != ArabicDialect.standardId && dialect.assetPath != null) {
        try {
          final dialectJson = await rootBundle.loadString(dialect.assetPath!);
          final Map<String, dynamic> dialectMap = json.decode(dialectJson);
          dialectMap.forEach((key, value) {
            merged[key] = value.toString();
          });
        } catch (_) {
          // الرجوع الهادئ إلى العربية الفصحى عند تعذر قراءة ملف اللهجة
        }
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
        LocalizationHelper.currentLanguage == lc &&
        (lc != 'ar' || LocalizationHelper.currentArabicDialect == arabicDialect)) {
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
  final String arabicDialect;

  const AppLocalizationsDelegate({
    this.arabicDialect = ArabicDialect.standardId,
  });

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
    Locale('fr'),
    Locale('es'),
  ];

  @override
  bool isSupported(Locale locale) {
    return supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(
      locale,
      arabicDialect: arabicDialect,
    );
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) =>
      old.arabicDialect != arabicDialect;
}
