import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../business/app_feature_flags.dart';

/// خدمة إدارة وتخزين تفضيلات المستخدم المحلية بصورة دائمة
/// تشمل: نمط المظهر (تلقائي / فاتح / داكن) ولغة التطبيق والعملة الافتراضية
class PreferencesService {
  PreferencesService._internal();
  static final PreferencesService instance = PreferencesService._internal();

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyLocaleCode = 'app_locale_code';
  static const String _keyOnboardingCompleted = 'app_onboarding_completed';
  static const String _keyBusinessMode = 'app_business_mode';
  static const String _keyBusinessName = 'app_business_name';
  static const String _keyBusinessPhone = 'app_business_phone';
  static const String _keyBusinessAddress = 'app_business_address';
  static const String _keyInvoiceFooterNote = 'app_invoice_footer_note';
  static const String _keyDefaultCurrency = 'app_default_currency';
  static const String _keyMultiCurrencyEnabled = 'app_multi_currency_enabled';
  static const String _keyWeeklyBackupReminder = 'app_weekly_backup_reminder';
  static const String _keyLastBackupAt = 'app_last_backup_at';
  static const String _keyDailyOrderCap = 'daily_order_cap';
  static const String _keyFeatureOverrides = 'app_feature_overrides_json';

  SharedPreferences? _prefs;

  /// تهيئة الخدمة مع التخزين المحلي
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// استرجاع نمط المظهر المحفوظ (الافتراضي هو نمط النظام)
  ThemeMode getThemeMode() {
    final modeStr = _prefs?.getString(_keyThemeMode);
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// حفظ نمط المظهر المفضل للمستخدم
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }

    await prefs.setString(_keyThemeMode, modeStr);
  }

  /// استرجاع كود اللغة المفضل للمستخدم
  String getLocaleCode() {
    return _prefs?.getString(_keyLocaleCode) ?? 'ar';
  }

  /// حفظ كود اللغة المفضل للمستخدم
  Future<void> setLocaleCode(String code) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyLocaleCode, code);
  }

  /// استرجاع حالة إكمال شاشات الترحيب والتعريف (Onboarding)
  bool isOnboardingCompleted() {
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// تعيين حالة إكمال شاشات الترحيب والتعريف (Onboarding)
  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_keyOnboardingCompleted, completed);
  }

  /// وضع النشاط التجاري (بائع بسيط / أسر منتجة / حرف ومشغولات / متجر تجزئة / تجارة وشحنات)
  String getBusinessMode() {
    return _prefs?.getString(_keyBusinessMode) ?? 'productive_family';
  }

  bool get isProductiveFamilyMode => getBusinessMode() != 'trade_logistics';

  Future<void> setBusinessMode(
    String mode, {
    bool resetFeatureOverrides = false,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyBusinessMode, mode);
    if (resetFeatureOverrides) {
      await prefs.remove(_keyFeatureOverrides);
    }
  }

  /// أعلام إظهار/إخفاء الميزات بناءً على الدور الحالي + التخصيصات اليدوية
  AppFeatureFlags getFeatureFlags() {
    final base = AppFeatureFlags.defaultsForMode(getBusinessMode());
    final raw = _prefs?.getString(_keyFeatureOverrides);
    if (raw == null || raw.trim().isEmpty) return base;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return base.applyOverrides(decoded);
      }
    } catch (_) {}
    return base;
  }

  Future<void> setFeatureOverride(String featureKey, bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    Map<String, dynamic> map = {};
    final raw = prefs.getString(_keyFeatureOverrides);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    map[featureKey] = enabled;
    await prefs.setString(_keyFeatureOverrides, json.encode(map));
  }

  Future<void> clearFeatureOverrides() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.remove(_keyFeatureOverrides);
  }

  /// بيانات هوية المشروع / الأسرة المنتجة (تظهر في الفواتير ورسائل الواتساب)
  String getBusinessName() => _prefs?.getString(_keyBusinessName) ?? '';

  Future<void> setBusinessName(String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyBusinessName, value.trim());
  }

  String getBusinessPhone() => _prefs?.getString(_keyBusinessPhone) ?? '';

  Future<void> setBusinessPhone(String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyBusinessPhone, value.trim());
  }

  String getBusinessAddress() => _prefs?.getString(_keyBusinessAddress) ?? '';

  Future<void> setBusinessAddress(String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyBusinessAddress, value.trim());
  }

  String getInvoiceFooterNote() =>
      _prefs?.getString(_keyInvoiceFooterNote) ?? '';

  Future<void> setInvoiceFooterNote(String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyInvoiceFooterNote, value.trim());
  }

  /// العملة الأساسية الافتراضية للمشروع
  String getDefaultCurrency() {
    return _prefs?.getString(_keyDefaultCurrency) ?? 'yer';
  }

  Future<void> setDefaultCurrency(String currencyCode) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyDefaultCurrency, currencyCode);
  }

  /// هل تعدد العملات وأسعار الصرف مفعّلة للمستخدم؟
  /// افتراضياً: معطّل في وضع الأسر المنتجة ومفعّل في وضع التجارة والشحنات
  bool isMultiCurrencyEnabled() {
    final stored = _prefs?.getBool(_keyMultiCurrencyEnabled);
    if (stored != null) return stored;
    return !isProductiveFamilyMode;
  }

  Future<void> setMultiCurrencyEnabled(bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_keyMultiCurrencyEnabled, enabled);
  }

  /// التذكير الأسبوعي لحفظ نسخة احتياطية
  bool isWeeklyBackupReminderEnabled() {
    return _prefs?.getBool(_keyWeeklyBackupReminder) ?? false;
  }

  Future<void> setWeeklyBackupReminderEnabled(bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_keyWeeklyBackupReminder, enabled);
  }

  /// تاريخ آخر نسخة احتياطية محفوظة
  DateTime? getLastBackupAt() {
    final raw = _prefs?.getString(_keyLastBackupAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastBackupAt(DateTime dt) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyLastBackupAt, dt.toIso8601String());
  }

  /// الحد الأقصى للطلبات اليومية (السعة الاستيعابية اليومية؛ 0 = غير مفعّل)
  int getDailyOrderCap() => _prefs?.getInt(_keyDailyOrderCap) ?? 0;

  Future<void> setDailyOrderCap(int cap) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_keyDailyOrderCap, cap < 0 ? 0 : cap);
  }
}
