import 'package:amtr/core/app.dart';
import 'package:amtr/core/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'core/localization/localization.dart';
import 'core/services/currency_service.dart';
import 'core/services/reminder_service.dart';

export 'package:amtr/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد مسار مجلد الترجمات الموحد لمكتبة localization
  LocalJsonLocalization.delegate.directories = ['i18n'];

  // تهيئة قاعدة البيانات المحلية وخدمة العملات والترجمة الأولية والتفضيلات والتنبيهات
  await AppDatabase.instance.database;
  await PreferencesService.instance.init();
  await CurrencyService.instance.init();
  await ReminderService.instance.init();
  await LocalizationHelper.load('ar');

  runApp(const RetailAssistantApp());
}
