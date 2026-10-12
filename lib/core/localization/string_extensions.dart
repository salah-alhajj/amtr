import 'package:flutter/widgets.dart';
import 'package:localization/localization.dart';
import 'app_localizations.dart';
import 'localization_helper.dart';

/// امتدادات السلاسل النصية للترجمة الفورية
/// تدعم استدعاء .i18n() و .tr() و .trParams()
extension LocalizedStringExtensions on String {
  /// ترجمة المفتاح عبر AppLocalizations إذا توفر السياق
  String tr(BuildContext context, {Map<String, String>? params}) {
    return AppLocalizations.of(context).translate(this, params: params);
  }

  /// ترجمة المفتاح مع استبدال المعاملات المعرفة
  String trParams(Map<String, String> params) {
    // 1. تجربة الترجمة عبر localization package
    String translated = i18n();
    if (translated == this) {
      // 2. تجربة الترجمة عبر LocalizationHelper إذا كانت القيمة مساوية للمفتاح
      translated = LocalizationHelper.translate(this);
    }

    params.forEach((key, value) {
      translated = translated.replaceAll('{$key}', value);
      translated = translated.replaceAll('%s{$key}', value);
    });

    return translated;
  }
}
