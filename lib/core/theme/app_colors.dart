import 'package:flutter/material.dart';

/// لوحة الألوان المستوحاة من فلسفة تصميم آبل (Apple iOS HIG)
/// قائمة على درجات الأزرق والأخضر والتدرجات الطبيعية الفاخرة بينهما.
class AppColors {
  // الألوان الأساسية
  static const Color primaryBlue = Color(0xFF007AFF); // أزرق آبل الشهير
  static const Color primaryGreen = Color(0xFF059669); // أخضر زمردي فاخر
  static const Color vibrantTeal = Color(0xFF06B6D4); // تركواز نابض
  static const Color mintGreen = Color(0xFF10B981); // نعناعي ناعم
  static const Color deepNavy = Color(0xFF0A2540); // كحلي عميق

  // التدرجات اللونية (Apple Gradient Accents)
  static const LinearGradient appleGradient = LinearGradient(
    colors: [primaryBlue, primaryGreen],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0051C8), Color(0xFF047857)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient softTealGradient = LinearGradient(
    colors: [Color(0xFFE0F2FE), Color(0xFFD1FAE5)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // ألوان الخلفيات والأسطح
  static const Color scaffoldBackground = Color(0xFFF8F9FA); // رمادي ناعم جداً
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);

  // ألوان الحدود والفواصل (Subtle Apple Borders)
  static const Color borderSubtle = Color(0xFFE5E7EB);
  static const Color borderDivider = Color(0xFFEEF0F2);

  // ألوان النصوص
  static const Color textPrimary = Color(0xFF111827); // أسود مائل للفحمي
  static const Color textSecondary = Color(0xFF6B7280); // رمادي متوسط
  static const Color textTertiary = Color(0xFF9CA3AF); // رمادي خفيف

  // ألوان الحالات والإنذارات
  static const Color statusSuccess = Color(0xFF10B981); // مسدد
  static const Color statusWarning = Color(0xFFF59E0B); // مسدد جزئياً
  static const Color statusDanger = Color(0xFFEF4444); // دين / معلق
  static const Color statusInfo = Color(0xFF3B82F6); // جاري المعالجة

  // ==========================================
  // ألوان النمط الداكن (Apple iOS Dark Mode Palette)
  // ==========================================
  static const Color darkScaffoldBackground = Color(0xFF000000); // أسود عميق نقي (OLED Pure Black)
  static const Color darkBackgroundLight = Color(0xFF0D1117); // رمادي فحمي فائق النعومة
  static const Color darkSurfaceCard = Color(0xFF1C1C1E); // سطح البطاقات في نمط آبل الداكن
  static const Color darkSurfaceMuted = Color(0xFF2C2C2E); // الأسطح الفرعية المكتومة
  static const Color darkSurfaceWhite = Color(0xFF1C1C1E); // بديل الأبيض في النمط الداكن
  static const Color darkSurfaceElevated = Color(0xFF242426); // الأسطح المرتفعة

  // ألوان الحدود والفواصل في النمط الداكن
  static const Color darkBorderSubtle = Color(0xFF2C2C2E); // حدود داكنة ناعمة
  static const Color darkBorderDivider = Color(0xFF38383A); // فواصل رمادية رقيقة

  // ألوان النصوص في النمط الداكن
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // نص أبيض ناصع
  static const Color darkTextSecondary = Color(0xFF8E8E93); // نص رمادي آبل الكلاسيكي
  static const Color darkTextTertiary = Color(0xFF636366); // رمادي مكتوم للعناصر الثانوية

  // درجات الألوان المشبعة المضيئة للنمط الداكن (Apple Dark Accents)
  static const Color darkPrimaryBlue = Color(0xFF0A84FF); // أزرق آبل المضيء للنمط الليلي
  static const Color darkPrimaryGreen = Color(0xFF30D158); // أخضر زمردي نيون للنمط الليلي
  static const Color darkVibrantTeal = Color(0xFF64D2FF); // تركواز سماوي مضيء
  static const Color darkStatusDanger = Color(0xFFFF453A); // أحمر تحذيري مضيء
  static const Color darkStatusWarning = Color(0xFFFF9F0A); // برتقالي تحذيري مضيء

  // ==========================================
  // توابع استجابة ديناميكية لنمط المظهر (Theme Aware Resolvers)
  // ==========================================
  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color getTextTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextTertiary : textTertiary;

  static Color getSurfaceCard(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceCard : surfaceCard;

  static Color getSurfaceMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceMuted : surfaceMuted;

  static Color getBorderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorderSubtle : borderSubtle;

  static Color getBorderDivider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorderDivider : borderDivider;

  static Color getPrimaryBlue(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPrimaryBlue : primaryBlue;

  static Color getPrimaryGreen(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPrimaryGreen : primaryGreen;
}

/// امتداد فوري وسلس على BuildContext لجلب ألوان النمط المتكيف
extension AppThemeContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get textPrimary => isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondary => isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get textTertiary => isDarkMode ? AppColors.darkTextTertiary : AppColors.textTertiary;
  Color get surfaceCard => isDarkMode ? AppColors.darkSurfaceCard : AppColors.surfaceCard;
  Color get surfaceMuted => isDarkMode ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted;
  Color get borderSubtle => isDarkMode ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
  Color get borderDivider => isDarkMode ? AppColors.darkBorderDivider : AppColors.borderDivider;
  Color get primaryBlue => isDarkMode ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
  Color get primaryGreen => isDarkMode ? AppColors.darkPrimaryGreen : AppColors.primaryGreen;
}

