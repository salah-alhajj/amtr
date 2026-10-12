import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة وتخزين تفضيلات المستخدم المحلية بصورة دائمة
/// تشمل: نمط المظهر (تلقائي / فاتح / داكن) ولغة التطبيق والعملة الافتراضية
class PreferencesService {
  PreferencesService._internal();
  static final PreferencesService instance = PreferencesService._internal();

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyLocaleCode = 'app_locale_code';
  static const String _keyOnboardingCompleted = 'app_onboarding_completed';

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
}
