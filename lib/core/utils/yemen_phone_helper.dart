import '../localization/localization.dart';

/// مشغلو شبكات الاتصالات في اليمن
enum YemenTelecomOperator {
  yemenMobile,
  sabafon,
  you,
  y,
  landline,
  saudi,
  international,
  unknown,
}

/// مساعد متخصص للتعامل مع أرقام الهواتف اليمنية، والتحقق منها، وتنسيقها للعرض والاتصال والواتساب
class YemenPhoneHelper {
  YemenPhoneHelper._();

  /// تحويل الأرقام العربية المشرقية (٠-٩) إلى أرقام لاتينية (0-9)
  static String convertArabicIndicDigits(String input) {
    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String result = input;
    for (int i = 0; i < arabicIndic.length; i++) {
      result = result.replaceAll(arabicIndic[i], '$i');
    }
    return result;
  }

  /// تنظيف النص البرمجي للرقم مع الإبقاء على الأرقام وعلامة + الأولى
  static String cleanPhoneNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final converted = convertArabicIndicDigits(raw.trim());
    final hasPlus = converted.startsWith('+');
    final digitsOnly = converted.replaceAll(RegExp(r'[^0-9]'), '');
    return hasPlus ? '+$digitsOnly' : digitsOnly;
  }

  /// تجهيز الرقم لرابط الاتصال المباشر tel:
  static String cleanForDialing(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final cleaned = cleanPhoneNumber(raw);
    return cleaned.replaceAll(RegExp(r'[\s\-]'), '');
  }

  /// تجهيز الرقم لرابط واتساب بالصيغة الدولية المعتمدة (E.164 بدون علامة + وبدون أصفار البداية)
  static String cleanForWhatsApp(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    String digits = convertArabicIndicDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');

    // إزالة الأصفار الدولية في البداية 00
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // رقم يمني يبدأ بـ 07 (10 أرقام) -> 9677...
    if (digits.startsWith('07') && digits.length == 10) {
      return '967${digits.substring(1)}';
    }

    // رقم يمني جوال محلي (9 أرقام تبدأ بـ 7) -> 9677...
    if (digits.startsWith('7') && digits.length == 9) {
      return '967$digits';
    }

    // رقم هاتف أرضي يمني (يبدأ بـ 01..07) بطول 7 أو 8 أرقام -> 967...
    if (digits.startsWith('0') && digits.length >= 7 && digits.length <= 8) {
      return '967${digits.substring(1)}';
    }

    // رقم سعودي محلي (يبدأ بـ 05 وطوله 10) -> 9665...
    if (digits.startsWith('05') && digits.length == 10) {
      return '966${digits.substring(1)}';
    }

    // إذا كان بالفعل بصيغة دولية يمنية 9677...
    return digits;
  }

  /// استخراج المشغل أو نوع الشبكة لرقم الهاتف
  static YemenTelecomOperator getOperator(String? raw) {
    if (raw == null || raw.trim().isEmpty) return YemenTelecomOperator.unknown;
    String digits = convertArabicIndicDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('00967')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('967')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('00966')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('966')) {
      digits = digits.substring(3);
    }

    // إذا بدأ بصفر محلي (مثل 077... أو 05...)
    if (digits.startsWith('07') && digits.length == 10) {
      digits = digits.substring(1);
    } else if (digits.startsWith('05') && digits.length == 10) {
      return YemenTelecomOperator.saudi;
    }

    // شبكات الجوال اليمنية (7x)
    if (digits.length >= 2) {
      final prefix2 = digits.substring(0, 2);
      if (prefix2 == '77' || prefix2 == '78') {
        return YemenTelecomOperator.yemenMobile;
      }
      if (prefix2 == '71') {
        return YemenTelecomOperator.sabafon;
      }
      if (prefix2 == '73') {
        return YemenTelecomOperator.you;
      }
      if (prefix2 == '70') {
        return YemenTelecomOperator.y;
      }
    }

    // هاتف ثابت يمني (01 صنعاء، 02 عدن، 03 الحديدة، 04 تعز/إب، 05 حضرموت، 06 ذمار، 07 حجة/صعدة)
    if (digits.startsWith('0') && digits.length >= 7 && digits.length <= 9) {
      final first2 = digits.substring(0, 2);
      if (['01', '02', '03', '04', '05', '06', '07'].contains(first2)) {
        return YemenTelecomOperator.landline;
      }
    }
    if (digits.length >= 7 && digits.length <= 8 && ['1', '2', '3', '4', '5', '6', '7'].contains(digits[0])) {
      return YemenTelecomOperator.landline;
    }

    // تحقق من الأرقام الدولية
    final cleaned = cleanPhoneNumber(raw);
    if (cleaned.startsWith('+966') || cleaned.startsWith('00966')) {
      return YemenTelecomOperator.saudi;
    }
    if (cleaned.startsWith('+') || cleaned.startsWith('00')) {
      return YemenTelecomOperator.international;
    }

    return YemenTelecomOperator.unknown;
  }

  /// الحصول على التسمية المترجمة لاسم مشغل الشبكة
  static String getOperatorLabel(YemenTelecomOperator op) {
    switch (op) {
      case YemenTelecomOperator.yemenMobile:
        return 'operator_yemen_mobile'.i18n();
      case YemenTelecomOperator.sabafon:
        return 'operator_sabafon'.i18n();
      case YemenTelecomOperator.you:
        return 'operator_you'.i18n();
      case YemenTelecomOperator.y:
        return 'operator_y'.i18n();
      case YemenTelecomOperator.landline:
        return 'operator_landline'.i18n();
      case YemenTelecomOperator.saudi:
        return 'operator_saudi'.i18n();
      case YemenTelecomOperator.international:
        return 'operator_international'.i18n();
      case YemenTelecomOperator.unknown:
        return '';
    }
  }

  /// تنسيق الرقم للعرض الأنيق والقابل للقراءة (مثال: 771 234 567 أو +967 771 234 567)
  static String? formatForDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final converted = convertArabicIndicDigits(raw.trim());
    final hasPlus = converted.startsWith('+');
    final digits = converted.replaceAll(RegExp(r'[^0-9]'), '');

    // يمني دولي يبدأ بـ 967
    if ((hasPlus && digits.startsWith('967') && digits.length == 12) ||
        (!hasPlus && digits.startsWith('967') && digits.length == 12)) {
      final local = digits.substring(3); // 9 digits
      return '+967 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }

    // يمني دولي يبدأ بـ 00967
    if (digits.startsWith('00967') && digits.length == 14) {
      final local = digits.substring(5);
      return '+967 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }

    // رقم يمني جوال محلي 9 أرقام (مثال: 771234567)
    if (digits.length == 9 && digits.startsWith('7')) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }

    // رقم يمني يبدأ بـ 07 (10 أرقام)
    if (digits.length == 10 && digits.startsWith('07')) {
      final local = digits.substring(1);
      return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }

    // هاتف أرضي يمني (01xxxxxx, 02xxxxxx)
    if (digits.length >= 7 && digits.length <= 8 && digits.startsWith('0')) {
      return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
    }

    // رقم سعودي محلي (05xxxxxxxx)
    if (digits.length == 10 && digits.startsWith('05')) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }

    // رقم سعودي دولي (+966 5xxxxxxxx)
    if (digits.startsWith('9665') && digits.length == 12) {
      final local = digits.substring(3);
      return '+966 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
    }

    // إذا كان يحتوي بالفعل على تنسيق محدد أو رقم دولي آخر
    if (hasPlus) {
      return '+$digits';
    }
    return converted;
  }

  /// التحقق الشامل من صحة رقم الهاتف في سياق اليمن والأرقام الدولية
  static bool isValid(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final converted = convertArabicIndicDigits(raw.trim());
    final hasPlus = converted.startsWith('+');
    final digits = converted.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 7 || digits.length > 15) return false;

    // جوال يمني محلي 9 أرقام تبدأ بـ 7[01378]
    if (RegExp(r'^7[01378][0-9]{7}$').hasMatch(digits)) {
      return true;
    }

    // جوال يمني يبدأ بـ 07 (10 أرقام)
    if (RegExp(r'^07[01378][0-9]{7}$').hasMatch(digits)) {
      return true;
    }

    // جوال يمني دولي (9677... أو +9677... أو 009677...)
    if (RegExp(r'^(00967|967)7[01378][0-9]{7}$').hasMatch(digits)) {
      return true;
    }

    // هاتف أرضي يمني محلي أو دولي
    if (RegExp(r'^(0[1-7][0-9]{5,7}|(00967|967)[1-7][0-9]{5,7})$').hasMatch(digits)) {
      return true;
    }

    // رقم سعودي (محلي أو دولي)
    if (RegExp(r'^(05[0-9]{8}|(00966|966)5[0-9]{8})$').hasMatch(digits)) {
      return true;
    }

    // رقم دولي بصيغة معيارية تبدأ بـ + أو 00
    if (hasPlus || converted.startsWith('00')) {
      return digits.length >= 8 && digits.length <= 15;
    }

    // السماح أيضاً بأرقام عامة بين 7 و 14 رقماً إذا كانت متسقة
    return digits.length >= 7 && digits.length <= 14;
  }

  /// مدقق الحقل للنماذج (Forms) مع رسائل خطأ دقيقة
  static String? validate(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'validation_phone_required'.i18n() : null;
    }

    final converted = convertArabicIndicDigits(value.trim());
    final digits = converted.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 7 || digits.length > 15 || !isValid(value)) {
      return 'validation_phone_invalid'.i18n();
    }

    return null;
  }
}
