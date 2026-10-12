import 'package:flutter/material.dart';
import 'localization/localization.dart';

/// الثوابت وقيم التهيئة العامة للتطبيق
class AppConstants {
  // معرفات العملات
  static const String currencyYer = 'YER'; // ريال يمني (العملة الأساسية)
  static const String currencySar = 'SAR'; // ريال سعودي
  static const String currencyUsd = 'USD'; // دولار أمريكي

  /// الرمز المعتمد للريال السعودي طبقاً للبنك المركزي السعودي (SAMA) - الرمز الرسمي U+20C1
  static const String sarSymbol = '\u{20C1}';
  static const String yerSymbol = 'ر.ي';
  static const String usdSymbol = '\$';

  static String getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case currencySar:
        return sarSymbol;
      case currencyUsd:
        return usdSymbol;
      case currencyYer:
      default:
        return yerSymbol;
    }
  }

  static String getCurrencyName(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case currencySar:
        return 'currency_sar'.i18n();
      case currencyUsd:
        return 'currency_usd'.i18n();
      case currencyYer:
      default:
        return 'currency_yer'.i18n();
    }
  }

  // حالات الدفع للطلب الفردي
  static const String paymentPrepaid = 'prepaid'; // مسدد مقدماً
  static const String paymentDebt = 'debt'; // دين (آجل)
  static const String paymentCod = 'cod'; // مسدد يداً بيد
  static const String paymentPartial = 'partial'; // مسدد جزئياً (عربون)

  static String getPaymentStatusLabel(String status) {
    switch (status) {
      case paymentPrepaid:
        return 'payment_status_paid_advance'.i18n();
      case paymentDebt:
        return 'payment_status_debt_credit'.i18n();
      case paymentCod:
        return 'payment_status_hand_to_hand'.i18n();
      case paymentPartial:
        return 'payment_status_partial'.i18n();
      default:
        return status;
    }
  }

  static Color getPaymentStatusColor(String status) {
    switch (status) {
      case paymentPrepaid:
        return const Color(0xFF2E7D32); // أخضر داكن
      case paymentDebt:
        return const Color(0xFFC62828); // أحمر داكن
      case paymentCod:
        return const Color(0xFF0277BD); // أزرق
      case paymentPartial:
        return const Color(0xFFEF6C00); // برتقالي
      default:
        return Colors.grey;
    }
  }

  // محطات الشحنة المجمعة
  static const String shipmentDispatched = 'dispatched'; // تم التسليم للنقل
  static const String shipmentCheckpoint = 'checkpoint_reached'; // وصل لنقطة الاستلام
  static const String shipmentDistribution = 'distribution_ready'; // وصل للتوزيع
  static const String shipmentDelivered = 'delivered'; // مكتملة ومسلّمة بالكامل

  static String getShipmentStatusLabel(String status) {
    switch (status) {
      case shipmentDispatched:
        return 'stage_dispatched'.i18n();
      case shipmentCheckpoint:
        return 'stage_arrived_hub'.i18n();
      case shipmentDistribution:
        return 'stage_ready_distribution'.i18n();
      case shipmentDelivered:
        return 'stage_delivered'.i18n();
      default:
        return status;
    }
  }

  static int getShipmentStatusStepIndex(String status) {
    switch (status) {
      case shipmentDispatched:
        return 0;
      case shipmentCheckpoint:
        return 1;
      case shipmentDistribution:
        return 2;
      case shipmentDelivered:
        return 3;
      default:
        return 0;
    }
  }

  static Color getShipmentStatusColor(String status) {
    switch (status) {
      case shipmentDispatched:
        return const Color(0xFF007AFF);
      case shipmentCheckpoint:
        return const Color(0xFFFF9500);
      case shipmentDistribution:
        return const Color(0xFF34C759);
      case shipmentDelivered:
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  // حالات استلام العميل للطلب الفردي
  static const String orderStatusPending = 'pending'; // بانتظار الشراء
  static const String orderStatusPurchased = 'purchased'; // تم الشراء
  static const String orderStatusInCargo = 'in_cargo'; // ضمن شحنة نقل
  static const String orderStatusReady = 'ready'; // جاهز للتسليم
  static const String orderStatusDelivered = 'delivered'; // تم التسليم للعميل

  static String getOrderStatusLabel(String status) {
    switch (status) {
      case orderStatusPending:
        return 'item_status_awaiting_purchase'.i18n();
      case orderStatusPurchased:
        return 'item_status_purchased'.i18n();
      case orderStatusInCargo:
        return 'item_status_in_transit'.i18n();
      case orderStatusReady:
        return 'item_status_ready_for_delivery'.i18n();
      case orderStatusDelivered:
        return 'item_status_delivered_to_customer'.i18n();
      default:
        return status;
    }
  }

  static Color getOrderStatusColor(String status) {
    switch (status) {
      case orderStatusPending:
        return const Color(0xFF8E8E93);
      case orderStatusPurchased:
        return const Color(0xFF5856D6);
      case orderStatusInCargo:
        return const Color(0xFF007AFF);
      case orderStatusReady:
        return const Color(0xFFFF9500);
      case orderStatusDelivered:
        return const Color(0xFF34C759);
      default:
        return Colors.grey;
    }
  }
}
