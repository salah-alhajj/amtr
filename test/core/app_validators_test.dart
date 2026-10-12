import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/localization/localization.dart';
import 'package:amtr/core/utils/app_validators.dart';
import 'package:amtr/core/utils/yemen_phone_helper.dart';

void main() {
  setUpAll(() {
    LocalizationHelper.setStrings({
      'validation_required': 'هذا الحقل مطلوب',
      'validation_name_too_short': 'يجب ألا يقل الاسم عن حرفين',
      'validation_name_invalid': 'يرجى إدخال اسم صحيح يحتوي على حروف',
      'customer_name_required': 'يرجى إدخال اسم العميل',
      'validation_phone_required': 'يرجى إدخال رقم الهاتف',
      'validation_phone_invalid': 'يرجى إدخال رقم هاتف يمني صحيح (مثال: 77xxxxxxx أو +967)',
      'operator_yemen_mobile': 'يمن موبايل',
      'operator_sabafon': 'سبأفون',
      'operator_you': 'يو (YOU)',
      'operator_y': 'واي',
      'operator_landline': 'هاتف ثابت',
      'operator_saudi': 'رقم سعودي',
      'operator_international': 'رقم دولي',
      'validation_quantity_required': 'يرجى تحديد الكمية',
      'validation_quantity_min': 'الكمية يجب أن تكون {min} على الأقل',
      'validation_quantity_max': 'الكمية تتجاوز الحد الأقصى ({max})',
      'validation_number_invalid': 'يرجى إدخال رقم صحيح',
      'validation_amount_required': 'يرجى إدخال المبلغ',
      'validation_amount_negative': 'لا يمكن أن تكون القيمة سالبة',
      'validation_amount_positive': 'يجب أن تكون القيمة أكبر من الصفر',
      'validation_amount_too_large': 'القيمة المدخلة كبيرة جداً',
      'validation_amount_exceeds_total': 'المبلغ المدفوع يتجاوز إجمالي الطلب',
      'validation_rate_required': 'يرجى إدخال سعر الصرف',
      'validation_rate_positive': 'سعر الصرف يجب أن يكون أكبر من الصفر',
      'validation_route_too_short': 'يجب ألا يقل عنوان المسار عن 3 أحرف',
      'validation_item_name_too_short': 'اسم الغرض قصير جداً (حرفان على الأقل)',
      'item_name_required': 'يرجى إدخال اسم الغرض',
      'shipment_route_required': 'يرجى إدخال عنوان الشحنة',
      'validation_notes_max_length': 'الملاحظات لا يمكن أن تتجاوز {max} حرفاً',
    }, 'ar');
  });

  group('AppValidators Unit Tests', () {
    test('customerName validator rejects empty, too short, or non-letter values', () {
      expect(AppValidators.customerName(null), 'يرجى إدخال اسم العميل');
      expect(AppValidators.customerName('   '), 'يرجى إدخال اسم العميل');
      expect(AppValidators.customerName('أ'), 'يجب ألا يقل الاسم عن حرفين');
      expect(AppValidators.customerName('12345'), 'يرجى إدخال اسم صحيح يحتوي على حروف');
      expect(AppValidators.customerName('...---'), 'يرجى إدخال اسم صحيح يحتوي على حروف');
      expect(AppValidators.customerName('محمد العولقي'), isNull);
      expect(AppValidators.customerName('John Doe'), isNull);
    });

    test('phone validator strictly checks Yemen phone formats and digit counts', () {
      // Optional when empty
      expect(AppValidators.phone(null, isRequired: false), isNull);
      expect(AppValidators.phone('', isRequired: false), isNull);

      // Required check
      expect(AppValidators.phone(null, isRequired: true), 'يرجى إدخال رقم الهاتف');

      // Invalid patterns
      expect(AppValidators.phone('12345'), 'يرجى إدخال رقم هاتف يمني صحيح (مثال: 77xxxxxxx أو +967)');
      expect(AppValidators.phone('abcdefg'), 'يرجى إدخال رقم هاتف يمني صحيح (مثال: 77xxxxxxx أو +967)');
      expect(AppValidators.phone('777123456789012345'), 'يرجى إدخال رقم هاتف يمني صحيح (مثال: 77xxxxxxx أو +967)');

      // Valid Yemen phone numbers
      expect(AppValidators.phone('771234567'), isNull); // Yemen Mobile
      expect(AppValidators.phone('780123456'), isNull); // Yemen Mobile 4G
      expect(AppValidators.phone('711234567'), isNull); // Sabafon
      expect(AppValidators.phone('731234567'), isNull); // You
      expect(AppValidators.phone('701234567'), isNull); // Y
      expect(AppValidators.phone('0771234567'), isNull); // With leading zero
      expect(AppValidators.phone('+967771234567'), isNull); // International with plus
      expect(AppValidators.phone('967771234567'), isNull); // International without plus
      expect(AppValidators.phone('01234567'), isNull); // Sanaa Landline
      expect(AppValidators.phone('02234567'), isNull); // Aden Landline

      // International / Expatriate numbers
      expect(AppValidators.phone('+966501234567'), isNull);
      expect(AppValidators.phone('0501234567'), isNull);

      // Arabic-Indic digits conversion
      expect(AppValidators.phone('٧٧١٢٣٤٥٦٧'), isNull);
    });

    test('quantity validator enforces integer range 1 to 10000', () {
      expect(AppValidators.quantity(null), 'يرجى تحديد الكمية');
      expect(AppValidators.quantity(''), 'يرجى تحديد الكمية');
      expect(AppValidators.quantity('abc'), 'يرجى إدخال رقم صحيح');
      expect(AppValidators.quantity('0'), 'الكمية يجب أن تكون 1 على الأقل');
      expect(AppValidators.quantity('-5'), 'الكمية يجب أن تكون 1 على الأقل');
      expect(AppValidators.quantity('15000'), 'الكمية تتجاوز الحد الأقصى (10000)');
      expect(AppValidators.quantity('1'), isNull);
      expect(AppValidators.quantity('250'), isNull);
      expect(AppValidators.quantity('10000'), isNull);
    });

    test('positiveAmount validator enforces positive numbers and bounds', () {
      expect(AppValidators.positiveAmount(null), 'يرجى إدخال المبلغ');
      expect(AppValidators.positiveAmount('0', allowZero: false), 'يجب أن تكون القيمة أكبر من الصفر');
      expect(AppValidators.positiveAmount('0', allowZero: true), isNull);
      expect(AppValidators.positiveAmount('-10.5', allowZero: true), 'لا يمكن أن تكون القيمة سالبة');
      expect(AppValidators.positiveAmount('100.75'), isNull);
      expect(AppValidators.positiveAmount('999999999999'), 'القيمة المدخلة كبيرة جداً');
    });

    test('paidAmount validator ensures payments do not exceed total', () {
      expect(AppValidators.paidAmount('50.0', maxAmount: 100.0), isNull);
      expect(AppValidators.paidAmount('100.0', maxAmount: 100.0), isNull);
      expect(AppValidators.paidAmount('150.0', maxAmount: 100.0), 'المبلغ المدفوع يتجاوز إجمالي الطلب');
      expect(AppValidators.paidAmount('-10.0', maxAmount: 100.0), 'لا يمكن أن تكون القيمة سالبة');
    });

    test('exchangeRate validator rejects zero or negative rates', () {
      expect(AppValidators.exchangeRate(null), 'يرجى إدخال سعر الصرف');
      expect(AppValidators.exchangeRate('0'), 'سعر الصرف يجب أن يكون أكبر من الصفر');
      expect(AppValidators.exchangeRate('-5'), 'سعر الصرف يجب أن يكون أكبر من الصفر');
      expect(AppValidators.exchangeRate('530.50'), isNull);
    });

    test('shipmentRoute and itemName length validation', () {
      expect(AppValidators.shipmentRoute(null), 'يرجى إدخال عنوان الشحنة');
      expect(AppValidators.shipmentRoute('ab'), 'يجب ألا يقل عنوان المسار عن 3 أحرف');
      expect(AppValidators.shipmentRoute('شحنة صنعاء - الرياض'), isNull);

      expect(AppValidators.itemName(null), 'يرجى إدخال اسم الغرض');
      expect(AppValidators.itemName('x'), 'اسم الغرض قصير جداً (حرفان على الأقل)');
      expect(AppValidators.itemName('عطر شرقي فاخر'), isNull);
    });

    test('notes validator respects max length', () {
      expect(AppValidators.notes(null), isNull);
      expect(AppValidators.notes('ملاحظة عادية'), isNull);
      final longString = 'أ' * 501;
      expect(AppValidators.notes(longString, maxLength: 500), 'الملاحظات لا يمكن أن تتجاوز 500 حرفاً');
    });
  });

  group('AppFormatters Logical Input Restrictions', () {
    test('positiveDecimal formatter allows numbers and single dot, prevents negatives', () {
      final formatters = AppFormatters.positiveDecimal(decimalRange: 2, maxIntegerDigits: 6);

      // Typing a valid number
      var result = formatters.first.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '125.50'),
      );
      expect(result.text, '125.50');

      // Typing negative sign -> rejected
      result = formatters.first.formatEditUpdate(
        const TextEditingValue(text: '125'),
        const TextEditingValue(text: '-125'),
      );
      expect(result.text, '125');

      // Typing second dot -> rejected
      result = formatters.first.formatEditUpdate(
        const TextEditingValue(text: '125.5'),
        const TextEditingValue(text: '125.5.9'),
      );
      expect(result.text, '125.5');

      // Typing more than 2 decimal places -> rejected
      result = formatters.first.formatEditUpdate(
        const TextEditingValue(text: '125.50'),
        const TextEditingValue(text: '125.509'),
      );
      expect(result.text, '125.50');

      // Starting with dot -> converts to 0.
      result = formatters.first.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '.'),
      );
      expect(result.text, '0.');
    });

    test('phoneNumber formatter allows digits and leading plus only', () {
      final formatters = AppFormatters.phoneNumber();

      // Normal phone
      var result = formatters.first.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+967771234567'),
      );
      expect(result.text, '+967771234567');

      // Plus in the middle -> rejected
      result = formatters.first.formatEditUpdate(
        const TextEditingValue(text: '967'),
        const TextEditingValue(text: '967+77'),
      );
      expect(result.text, '967');

      // Letters -> rejected
      result = formatters.first.formatEditUpdate(
        const TextEditingValue(text: '7712'),
        const TextEditingValue(text: '7712abc'),
      );
      expect(result.text, '7712');
    });

    test('personName formatter accepts Arabic and Latin letters, rejects digits', () {
      final formatters = AppFormatters.personName();

      var result = formatters.first.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'علي أحمد'),
      );
      expect(result.text, 'علي أحمد');

      result = formatters.first.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'John Smith'),
      );
      expect(result.text, 'John Smith');

      // Trying to enter digits
      result = formatters.first.formatEditUpdate(
        const TextEditingValue(text: 'علي'),
        const TextEditingValue(text: 'علي123'),
      );
      expect(result.text, 'علي');
    });
  });

  group('YemenPhoneHelper Comprehensive Tests', () {
    test('Operator classification detects correct Yemen networks', () {
      expect(YemenPhoneHelper.getOperator('771234567'), YemenTelecomOperator.yemenMobile);
      expect(YemenPhoneHelper.getOperator('780123456'), YemenTelecomOperator.yemenMobile);
      expect(YemenPhoneHelper.getOperator('+967 771 234 567'), YemenTelecomOperator.yemenMobile);
      expect(YemenPhoneHelper.getOperator('711234567'), YemenTelecomOperator.sabafon);
      expect(YemenPhoneHelper.getOperator('731234567'), YemenTelecomOperator.you);
      expect(YemenPhoneHelper.getOperator('701234567'), YemenTelecomOperator.y);
      expect(YemenPhoneHelper.getOperator('01234567'), YemenTelecomOperator.landline);
      expect(YemenPhoneHelper.getOperator('02234567'), YemenTelecomOperator.landline);
      expect(YemenPhoneHelper.getOperator('+966501234567'), YemenTelecomOperator.saudi);
      expect(YemenPhoneHelper.getOperator('0501234567'), YemenTelecomOperator.saudi);
      expect(YemenPhoneHelper.getOperator('+12025550199'), YemenTelecomOperator.international);
    });

    test('formatForDisplay formats Yemen numbers into clear visual chunks', () {
      expect(YemenPhoneHelper.formatForDisplay('771234567'), '771 234 567');
      expect(YemenPhoneHelper.formatForDisplay('0771234567'), '771 234 567');
      expect(YemenPhoneHelper.formatForDisplay('+967771234567'), '+967 771 234 567');
      expect(YemenPhoneHelper.formatForDisplay('967771234567'), '+967 771 234 567');
      expect(YemenPhoneHelper.formatForDisplay('01234567'), '01 234 567');
      expect(YemenPhoneHelper.formatForDisplay('+966501234567'), '+966 50 123 4567');
    });

    test('cleanForWhatsApp prepares valid WhatsApp E.164 without plus or zeros', () {
      expect(YemenPhoneHelper.cleanForWhatsApp('771234567'), '967771234567');
      expect(YemenPhoneHelper.cleanForWhatsApp('0771234567'), '967771234567');
      expect(YemenPhoneHelper.cleanForWhatsApp('+967 771 234 567'), '967771234567');
      expect(YemenPhoneHelper.cleanForWhatsApp('00967 771234567'), '967771234567');
      expect(YemenPhoneHelper.cleanForWhatsApp('0501234567'), '966501234567');
      expect(YemenPhoneHelper.cleanForWhatsApp('+966 50 123 4567'), '966501234567');
    });

    test('cleanForDialing strips spaces for safe tel: URI', () {
      expect(YemenPhoneHelper.cleanForDialing('+967 771 234 567'), '+967771234567');
      expect(YemenPhoneHelper.cleanForDialing('771 234 567'), '771234567');
    });

    test('convertArabicIndicDigits transforms eastern numerals', () {
      expect(YemenPhoneHelper.convertArabicIndicDigits('٧٧١٢٣٤٥٦٧'), '771234567');
      expect(YemenPhoneHelper.convertArabicIndicDigits('+٩٦٧ ٧٧١ ٢٣٤ ٥٦٧'), '+967 771 234 567');
    });
  });
}
