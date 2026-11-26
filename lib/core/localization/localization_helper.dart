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
  static String? _targetLanguage;
  static String? _targetArabicDialect;
  static bool _loadedFromAssets = false;
  static int _loadVersion = 0;
  static final Map<String, Map<String, String>> _assetMapCache = {};

  static String get currentLanguage => _currentLanguage;
  static String get currentArabicDialect => _currentArabicDialect;

  /// قراءة وتحليل ملف JSON من أصول التطبيق بكفاءة عالية مع تخزين مؤقت للخريطة المحلَّلة
  /// (يستخدم rootBundle.load + utf8.decode مباشرة لتجنّب تعليق Isolate في اختبارات FakeAsync وتسريع تبديل اللهجات)
  static Future<Map<String, String>> loadAssetMap(String assetPath) async {
    final cached = _assetMapCache[assetPath];
    if (cached != null) {
      return cached;
    }
    final byteData = await rootBundle.load(assetPath);
    final jsonString = utf8.decode(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
    final Map<String, dynamic> decoded = json.decode(jsonString);
    final mapped = Map<String, String>.unmodifiable(
      decoded.map((key, value) => MapEntry(key, value.toString())),
    );
    _assetMapCache[assetPath] = mapped;
    return mapped;
  }

  /// تسجيل الهدف المطلوب (اللغة واللهجة) قبل أي تحميل غير متزامن لمنع السباقات (Race Conditions)
  static void setTarget(String languageCode, {String? arabicDialect}) {
    final normalizedLang = languageCode.trim().isEmpty ? 'ar' : languageCode.trim();
    final effectiveDialect = normalizedLang == 'ar'
        ? ArabicDialect.fromId(arabicDialect).id
        : ArabicDialect.standardId;
    _targetLanguage = normalizedLang;
    _targetArabicDialect = effectiveDialect;
  }

  /// التحقق مما إذا كانت اللغة واللهجة المعطاة تطابق أحدث طلب نشط
  static bool matchesTarget(String languageCode, String arabicDialect) {
    if (_targetLanguage == null) return true;
    final normalizedLang = languageCode.trim().isEmpty ? 'ar' : languageCode.trim();
    final effectiveDialect = normalizedLang == 'ar'
        ? ArabicDialect.fromId(arabicDialect).id
        : ArabicDialect.standardId;
    return _targetLanguage == normalizedLang &&
        (normalizedLang != 'ar' || _targetArabicDialect == effectiveDialect);
  }

  /// التحقق من أن ملفات الأصول لهذه اللغة واللهجة محمّلة مسبقاً في الذاكرة
  static bool isLoadedFromAssets(String languageCode, String arabicDialect) {
    final normalizedLang = languageCode.trim().isEmpty ? 'ar' : languageCode.trim();
    final effectiveDialect = normalizedLang == 'ar'
        ? ArabicDialect.fromId(arabicDialect).id
        : ArabicDialect.standardId;
    return _loadedFromAssets &&
        _localizedStrings != null &&
        _localizedStrings!.isNotEmpty &&
        _currentLanguage == normalizedLang &&
        (normalizedLang != 'ar' || _currentArabicDialect == effectiveDialect);
  }

  /// ضمان تزامن LocalizationService (المستخدم في .i18n()) مع الخريطة النشطة في LocalizationHelper
  static void ensureServiceSynced() {
    if (_localizedStrings != null && _localizedStrings!.isNotEmpty) {
      LocalizationService.instance.changeLanguageFromMap(
        Locale(_currentLanguage),
        _localizedStrings!,
      );
    }
  }

  /// تحميل ملف الترجمة وتحديث الذاكرة (مع دمج اللهجة العربية المختارة عند التفعيل)
  static Future<void> load(
    String languageCode, {
    String? arabicDialect,
    bool forceReload = false,
  }) async {
    final normalizedLang = languageCode.trim().isEmpty ? 'ar' : languageCode.trim();
    final effectiveDialect = normalizedLang == 'ar'
        ? ArabicDialect.fromId(
            arabicDialect ?? PreferencesService.instance.getArabicDialect(),
          ).id
        : ArabicDialect.standardId;

    setTarget(normalizedLang, arabicDialect: effectiveDialect);

    if (!forceReload &&
        _loadedFromAssets &&
        _localizedStrings != null &&
        _localizedStrings!.isNotEmpty &&
        _currentLanguage == normalizedLang &&
        _currentArabicDialect == effectiveDialect) {
      LocalizationService.instance.changeLanguageFromMap(
        Locale(normalizedLang),
        _localizedStrings!,
      );
      return;
    }

    final version = ++_loadVersion;

    try {
      final baseMap = await loadAssetMap('i18n/$normalizedLang.json');
      if (version != _loadVersion) return;

      final Map<String, String> mapped = Map<String, String>.from(baseMap);

      if (normalizedLang == 'ar' &&
          effectiveDialect != ArabicDialect.standardId) {
        final dialectObj = ArabicDialect.fromId(effectiveDialect);
        if (dialectObj.assetPath != null) {
          try {
            final dialectMap = await loadAssetMap(dialectObj.assetPath!);
            if (version != _loadVersion) return;
            mapped.addAll(dialectMap);
          } catch (_) {
            // الاحتفاظ بالترجمة العربية الأساسية عند تعذر تحميل ملف اللهجة
          }
        }
      }

      if (version != _loadVersion) return;

      _currentLanguage = normalizedLang;
      _currentArabicDialect = effectiveDialect;
      _localizedStrings = mapped;
      _loadedFromAssets = true;
      LocalizationService.instance.changeLanguageFromMap(
        Locale(normalizedLang),
        mapped,
      );
    } catch (_) {
      if (version != _loadVersion) return;
      if (_localizedStrings != null &&
          _localizedStrings!.isNotEmpty &&
          _currentLanguage == normalizedLang &&
          _currentArabicDialect == effectiveDialect) {
        return;
      }
      // الرجوع للغة العربية كخيار بديل آمن
      if (normalizedLang != 'ar') {
        await load('ar', arabicDialect: arabicDialect, forceReload: forceReload);
      } else {
        _currentLanguage = 'ar';
        _currentArabicDialect = effectiveDialect;
        _localizedStrings = {};
        _loadedFromAssets = false;
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
    bool fromAssets = false,
  }) {
    if (strings.isEmpty) return;
    final normalizedLang = languageCode.trim().isEmpty ? 'ar' : languageCode.trim();
    final effectiveDialect = normalizedLang == 'ar'
        ? (arabicDialect != null
            ? ArabicDialect.fromId(arabicDialect).id
            : _currentArabicDialect)
        : ArabicDialect.standardId;

    ++_loadVersion;
    _localizedStrings = strings;
    _currentLanguage = normalizedLang;
    _currentArabicDialect = effectiveDialect;
    _targetLanguage = normalizedLang;
    _targetArabicDialect = effectiveDialect;
    _loadedFromAssets = fromAssets;
    LocalizationService.instance.changeLanguageFromMap(
      Locale(normalizedLang),
      strings,
    );
  }
}

