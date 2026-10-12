import 'package:flutter/services.dart';
import '../localization/localization.dart';
import 'yemen_phone_helper.dart';

/// تنسيقات ومحددات الإدخال لتقييد الحقول بقيم منطقية فقط
class AppFormatters {
  AppFormatters._();

  /// الأعداد الصحيحة الموجبة فقط (الكميات)
  static List<TextInputFormatter> positiveInteger({int maxDigits = 5}) => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ];

  /// الأرقام العشرية الموجبة (الأسعار، التكاليف، أسعار الصرف)
  static List<TextInputFormatter> positiveDecimal({
    int decimalRange = 2,
    int maxIntegerDigits = 9,
  }) =>
      [
        _PositiveDecimalTextInputFormatter(
          decimalRange: decimalRange,
          maxIntegerDigits: maxIntegerDigits,
        ),
      ];

  /// أرقام الهواتف (علامة + اختيارية في البداية ثم أرقام فقط)
  static List<TextInputFormatter> phoneNumber({int maxLength = 16}) => [
        _PhoneNumberTextInputFormatter(maxLength: maxLength),
      ];

  /// أسماء الأشخاص (أحرف عربية ولاتينية ومسافات فقط، دون أرقام أو رموز غريبة)
  static List<TextInputFormatter> personName({int maxLength = 60}) => [
        FilteringTextInputFormatter.allow(
          RegExp(r"[a-zA-Z\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\s\.\'\-]"),
        ),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// أرقام التتبع والوثائق (أحرف إنجليزية، أرقام، شرطات)
  static List<TextInputFormatter> trackingNumber({int maxLength = 35}) => [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_/]')),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// أسماء الشركات والناقلين والمسارات
  static List<TextInputFormatter> generalText({int maxLength = 100}) => [
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// الملاحظات والوصف
  static List<TextInputFormatter> notes({int maxLength = 500}) => [
        LengthLimitingTextInputFormatter(maxLength),
      ];
}

/// مخصص تقييد الأرقام العشرية الموجبة بدقة
class _PositiveDecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;
  final int maxIntegerDigits;

  _PositiveDecimalTextInputFormatter({
    required this.decimalRange,
    required this.maxIntegerDigits,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // السماح بالحقل الفارغ
    if (text.isEmpty) {
      return newValue;
    }

    // لا يسمح بالبدء بفاصلة عشرية دون صفر
    if (text == '.') {
      return const TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    // السماح فقط بالأرقام ونقطة واحدة
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }

    // التحقق من طول الأعداد قبل وبعد الفاصلة
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts[0].length > maxIntegerDigits) {
        return oldValue;
      }
      if (parts.length > 1 && parts[1].length > decimalRange) {
        return oldValue;
      }
    } else {
      if (text.length > maxIntegerDigits) {
        return oldValue;
      }
    }

    return newValue;
  }
}

/// مخصص تقييد إدخال أرقام الهواتف (تحويل الأرقام المشرقية، السماح بعلامة + في البداية فقط وأرقام ومسافات)
class _PhoneNumberTextInputFormatter extends TextInputFormatter {
  final int maxLength;

  _PhoneNumberTextInputFormatter({required this.maxLength});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    // تحويل الأرقام المشرقية ٠-٩ إلى أرقام 0-9 تلقائياً
    final converted = YemenPhoneHelper.convertArabicIndicDigits(newValue.text);

    // يسمح بعلامة + فقط في الحرف الأول والباقي أرقام ومسافات
    if (!RegExp(r'^\+?[0-9\s\-]*$').hasMatch(converted)) {
      return oldValue;
    }
    final digitsOnly = converted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > maxLength) {
      return oldValue;
    }
    return newValue.copyWith(
      text: converted,
      selection: newValue.selection,
    );
  }
}


/// مدققات الحقول مع تقديم رسائل خطأ وتغذية راجعة واضحة
class AppValidators {
  AppValidators._();

  /// التحقق من الحقل الإجباري العام
  static String? requiredField(String? value, {String? customMessage}) {
    if (value == null || value.trim().isEmpty) {
      return customMessage ?? 'validation_required'.i18n();
    }
    return null;
  }

  /// التحقق من اسم العميل (حروف منطقية، حرفان على الأقل، بدون أرقام بحتة)
  static String? customerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'customer_name_required'.i18n();
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'validation_name_too_short'.i18n();
    }
    // يجب أن يحتوي على حرف واحد على الأقل
    if (!RegExp(r'[a-zA-Z\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(trimmed)) {
      return 'validation_name_invalid'.i18n();
    }
    return null;
  }

  /// التحقق من رقم الهاتف في سياق شبكات اليمن والأرقام الدولية
  static String? phone(String? value, {bool isRequired = false}) {
    return YemenPhoneHelper.validate(value, isRequired: isRequired);
  }

  /// التحقق من الكمية (عدد صحيح موجب 1 فأكثر حتى 10,000)
  static String? quantity(String? value, {int min = 1, int max = 10000}) {
    if (value == null || value.trim().isEmpty) {
      return 'validation_quantity_required'.i18n();
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'validation_number_invalid'.i18n();
    }
    if (parsed < min) {
      return 'validation_quantity_min'.trParams({'min': min.toString()});
    }
    if (parsed > max) {
      return 'validation_quantity_max'.trParams({'max': max.toString()});
    }
    return null;
  }

  /// التحقق من المبالغ والأسعار والتكاليف
  static String? positiveAmount(
    String? value, {
    bool allowZero = false,
    double max = 999999999.0,
    String? customRequiredMsg,
  }) {
    if (value == null || value.trim().isEmpty) {
      return customRequiredMsg ?? 'validation_amount_required'.i18n();
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'validation_number_invalid'.i18n();
    }
    if (allowZero) {
      if (parsed < 0) {
        return 'validation_amount_negative'.i18n();
      }
    } else {
      if (parsed <= 0) {
        return 'validation_amount_positive'.i18n();
      }
    }
    if (parsed > max) {
      return 'validation_amount_too_large'.i18n();
    }
    return null;
  }

  /// التحقق من المبلغ المدفوع ومقارنته بإجمالي الطلب
  static String? paidAmount(
    String? value, {
    double? maxAmount,
    bool allowEmpty = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : 'validation_amount_required'.i18n();
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'validation_number_invalid'.i18n();
    }
    if (parsed < 0) {
      return 'validation_amount_negative'.i18n();
    }
    if (maxAmount != null && maxAmount > 0 && parsed > (maxAmount + 0.01)) {
      return 'validation_amount_exceeds_total'.i18n();
    }
    return null;
  }

  /// التحقق من سعر الصرف (أكبر من الصفر ومنطقي)
  static String? exchangeRate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation_rate_required'.i18n();
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'validation_rate_positive'.i18n();
    }
    if (parsed > 10000000) {
      return 'validation_amount_too_large'.i18n();
    }
    return null;
  }

  /// التحقق من مسار/عنوان الشحنة
  static String? shipmentRoute(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'shipment_route_required'.i18n();
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'validation_route_too_short'.i18n();
    }
    return null;
  }

  /// التحقق من اسم الغرض في الطلب
  static String? itemName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'item_name_required'.i18n();
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'validation_item_name_too_short'.i18n();
    }
    return null;
  }

  /// التحقق من الملاحظات
  static String? notes(String? value, {int maxLength = 500}) {
    if (value != null && value.length > maxLength) {
      return 'validation_notes_max_length'.trParams({'max': maxLength.toString()});
    }
    return null;
  }
}
