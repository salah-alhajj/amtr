import 'package:mosaed/core/app.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'core/localization/localization.dart';
import 'core/services/currency_service.dart';
import 'core/services/reminder_service.dart';

export 'package:mosaed/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد مسار مجلد الترجمات الموحد لمكتبة localization
  LocalJsonLocalization.delegate.directories = ['i18n'];

  // تهيئة قاعدة البيانات المحلية وخدمة العملات والتفضيلات والتنبيهات
  await AppDatabase.instance.database;
  await PreferencesService.instance.init();
  await CurrencyService.instance.init();
  await ReminderService.instance.init();

  // تحميل اللغة واللهجة الإقليمية المحفوظتين قبل بناء أول إطار لمنع أي وميض أو تعارض
  final persistedLocaleCode = PreferencesService.instance.getLocaleCode();
  final effectiveLocaleCode =
      AppLanguage.supported.any((lang) => lang.code == persistedLocaleCode)
          ? persistedLocaleCode
          : 'ar';
  final persistedArabicDialect = PreferencesService.instance.getArabicDialect();
  await LocalizationHelper.load(
    effectiveLocaleCode,
    arabicDialect: persistedArabicDialect,
  );

  runApp(const RetailAssistantApp());
}
