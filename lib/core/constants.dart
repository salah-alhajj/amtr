import 'package:flutter/material.dart';
import 'localization/localization.dart';
import 'services/preferences_service.dart';

/// الثوابت وقيم التهيئة العامة للتطبيق
class AppConstants {
  // معرفات العملات
  static const String currencyYer = 'yer'; // ريال يمني (العملة الأساسية)
  static const String currencySar = 'SAR'; // ريال سعودي
  static const String currencyUsd = 'USD'; // دولار أمريكي

  /// الرمز المعتمد للريال السعودي طبقاً للبنك المركزي السعودي (SAMA) - الرمز الرسمي U+20C1
  static const String sarSymbol = '\u{20C1}';
  static final String yerSymbol = 'yer';
  static const String usdSymbol = '\$';

  static String getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case currencySar:
        return sarSymbol;
      case currencyUsd:
        return usdSymbol;
      case currencyYer:
      default:
        return yerSymbol.i18n();
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
  static const String paymentPrepaid = 'prepaid'; // مسدد مقدماً / مدفوع بالكامل
  static const String paymentDebt = 'debt'; // دين (آجل) / على الحساب
  static const String paymentCod = 'cod'; // مسدد يداً بيد / عند الاستلام
  static const String paymentPartial = 'partial'; // مسدد جزئياً (عربون) / دافع عربون

  // تصنيف المصروف (تشغيلي للمشروع أم مسحوبات شخصية للبيت)
  static const String expenseTypeBusiness = 'business';
  static const String expenseTypePersonal = 'personal';

  // وسيلة الدفع في حركات الصندوق
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodTransfer = 'transfer';

  static String getPaymentStatusLabel(String status, {bool? isProductiveFamily}) {
    final pfMode =
        isProductiveFamily ?? PreferencesService.instance.isProductiveFamilyMode;
    if (pfMode) {
      switch (status) {
        case paymentPrepaid:
          return 'pf_pay_prepaid'.i18n();
        case paymentDebt:
          return 'pf_pay_debt'.i18n();
        case paymentCod:
          return 'pf_pay_cod'.i18n();
        case paymentPartial:
          return 'pf_pay_partial'.i18n();
        default:
          return status;
      }
    }
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
  static const String shipmentCheckpoint =
      'checkpoint_reached'; // وصل لنقطة الاستلام
  static const String shipmentDistribution =
      'distribution_ready'; // وصل للتوزيع
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

  // أوضاع النشاط التجاري
  static const String businessModeProductiveFamily = 'productive_family';
  static const String businessModeTradeLogistics = 'trade_logistics';

  // طرق تسليم الطلب
  static const String deliveryPickup = 'pickup';
  static const String deliveryDelivery = 'delivery';

  // تصنيفات المنتجات للأسر المنتجة والبزنس الصغير
  static const List<String> productCategories = [
    'cat_food_sweets',
    'cat_perfume_bakhoor',
    'cat_fashion_sewing',
    'cat_gifts_crafts',
    'cat_general',
  ];

  // تصنيفات المصاريف التشغيلية
  static const List<String> expenseCategories = [
    'exp_cat_materials',
    'exp_cat_packaging',
    'exp_cat_delivery',
    'exp_cat_marketing',
    'exp_cat_petty_cash',
    'exp_cat_other',
  ];

  // طبيعة المنتج (بيع وشراء أو تصنيع وإنتاج)
  static const String productTypeResale = 'resale';
  static const String productTypeManufactured = 'manufactured';

  static String getProductTypeLabel(String type) {
    return type == productTypeManufactured
        ? 'product_type_manufactured'.i18n()
        : 'product_type_resale'.i18n();
  }

  static Color getProductTypeColor(String type) {
    return type == productTypeManufactured
        ? const Color(0xFF7C3AED)
        : const Color(0xFF0284C7);
  }

  // دورية المصروف (مرة واحدة / يومي / أسبوعي / شهري)
  static const String expenseRecurrenceOnce = 'once';
  static const String expenseRecurrenceDaily = 'daily';
  static const String expenseRecurrenceWeekly = 'weekly';
  static const String expenseRecurrenceMonthly = 'monthly';

  static const List<String> expenseRecurrences = [
    expenseRecurrenceOnce,
    expenseRecurrenceDaily,
    expenseRecurrenceWeekly,
    expenseRecurrenceMonthly,
  ];

  static String getExpenseRecurrenceLabel(String recurrence) {
    switch (recurrence) {
      case expenseRecurrenceDaily:
        return 'expense_recurrence_daily'.i18n();
      case expenseRecurrenceWeekly:
        return 'expense_recurrence_weekly'.i18n();
      case expenseRecurrenceMonthly:
        return 'expense_recurrence_monthly'.i18n();
      case expenseRecurrenceOnce:
      default:
        return 'expense_recurrence_once'.i18n();
    }
  }

  static Color getExpenseRecurrenceColor(String recurrence) {
    switch (recurrence) {
      case expenseRecurrenceDaily:
        return const Color(0xFF0284C7);
      case expenseRecurrenceWeekly:
        return const Color(0xFF7C3AED);
      case expenseRecurrenceMonthly:
        return const Color(0xFF059669);
      case expenseRecurrenceOnce:
      default:
        return const Color(0xFF64748B);
    }
  }

  // تصنيفات الموردين
  static const List<String> supplierCategories = [
    'sup_cat_materials',
    'sup_cat_packaging',
    'sup_cat_wholesale',
    'sup_cat_services',
    'sup_cat_general',
  ];

  // أنواع حركات دفتر حساب المورد
  static const String supplierTxPurchaseCredit = 'purchase_credit';
  static const String supplierTxPurchaseCash = 'purchase_cash';
  static const String supplierTxPayment = 'payment';

  // حالات توصيل الطلب مع المندوب
  static const String courierStatusNone = 'none';
  static const String courierStatusAssigned = 'assigned';
  static const String courierStatusDelivered = 'delivered';
  static const String courierStatusReturned = 'returned';

  // فترات دورة إعادة الطلب الذكية للمنتجات (بالأيام؛ 0 = غير مفعّل)
  static const List<int> reorderCyclePresets = [0, 7, 14, 30];

  // أنواع بنود التكاليف في قوالب ووصفات التصنيع
  static const String costItemMaterial = 'material';
  static const String costItemPackaging = 'packaging';
  static const String costItemLabor = 'labor';
  static const String costItemUtilities = 'utilities';
  static const String costItemOverhead = 'overhead';

  static const List<String> productionCostItemTypes = [
    costItemMaterial,
    costItemPackaging,
    costItemLabor,
    costItemUtilities,
    costItemOverhead,
  ];

  static String getProductionCostItemTypeLabel(String itemType) {
    switch (itemType) {
      case costItemMaterial:
        return 'mfg_cost_type_material'.i18n();
      case costItemPackaging:
        return 'mfg_cost_type_packaging'.i18n();
      case costItemLabor:
        return 'mfg_cost_type_labor'.i18n();
      case costItemUtilities:
        return 'mfg_cost_type_utilities'.i18n();
      case costItemOverhead:
      default:
        return 'mfg_cost_type_overhead'.i18n();
    }
  }

  static Color getProductionCostItemTypeColor(String itemType) {
    switch (itemType) {
      case costItemMaterial:
        return const Color(0xFF0284C7);
      case costItemPackaging:
        return const Color(0xFF0D9488);
      case costItemLabor:
        return const Color(0xFF7C3AED);
      case costItemUtilities:
        return const Color(0xFFD97706);
      case costItemOverhead:
      default:
        return const Color(0xFF64748B);
    }
  }

  // حالات دفعة الإنتاج (تعتيق/تخمير، جاهز، منتهي الصلاحية)
  static const String batchStatusCuring = 'curing';
  static const String batchStatusReady = 'ready';
  static const String batchStatusExpired = 'expired';

  static const List<String> batchStatuses = [
    batchStatusCuring,
    batchStatusReady,
    batchStatusExpired,
  ];

  static String getBatchStatusLabel(String status) {
    switch (status) {
      case batchStatusCuring:
        return 'batch_status_curing'.i18n();
      case batchStatusExpired:
        return 'batch_status_expired'.i18n();
      case batchStatusReady:
      default:
        return 'batch_status_ready'.i18n();
    }
  }

  static Color getBatchStatusColor(String status) {
    switch (status) {
      case batchStatusCuring:
        return const Color(0xFFD97706); // كهرماني / قيد التعتيق
      case batchStatusExpired:
        return const Color(0xFFDC2626); // أحمر / منتهي الصلاحية
      case batchStatusReady:
      default:
        return const Color(0xFF059669); // أخضر / جاهز
    }
  }

  // أسباب تسجيل الهدر والتالف
  static const String wasteReasonSpoiled = 'spoiled';
  static const String wasteReasonDamaged = 'damaged';
  static const String wasteReasonExpired = 'expired';
  static const String wasteReasonRemake = 'remake';
  static const String wasteReasonOther = 'other';

  static const List<String> wasteReasons = [
    wasteReasonSpoiled,
    wasteReasonDamaged,
    wasteReasonExpired,
    wasteReasonRemake,
    wasteReasonOther,
  ];

  static String getWasteReasonLabel(String reason) {
    switch (reason) {
      case wasteReasonSpoiled:
        return 'waste_reason_spoiled'.i18n();
      case wasteReasonDamaged:
        return 'waste_reason_damaged'.i18n();
      case wasteReasonExpired:
        return 'waste_reason_expired'.i18n();
      case wasteReasonRemake:
        return 'waste_reason_remake'.i18n();
      case wasteReasonOther:
      default:
        return 'waste_reason_other'.i18n();
    }
  }

  // حالات استلام العميل للطلب الفردي
  static const String orderStatusPending = 'pending'; // بانتظار الشراء / طلب جديد
  static const String orderStatusPurchased = 'purchased'; // تم الشراء / قيد التحضير
  static const String orderStatusInCargo = 'in_cargo'; // ضمن شحنة نقل / مع المندوب
  static const String orderStatusReady = 'ready'; // جاهز للتسليم
  static const String orderStatusDelivered = 'delivered'; // تم التسليم للعميل

  static String getOrderStatusLabel(String status, {bool? isProductiveFamily}) {
    final pfMode =
        isProductiveFamily ?? PreferencesService.instance.isProductiveFamilyMode;
    if (pfMode) {
      switch (status) {
        case orderStatusPending:
          return 'pf_status_new'.i18n();
        case orderStatusPurchased:
          return 'pf_status_preparing'.i18n();
        case orderStatusInCargo:
          return 'pf_status_out_delivery'.i18n();
        case orderStatusReady:
          return 'item_status_ready_for_delivery'.i18n();
        case orderStatusDelivered:
          return 'item_status_delivered_to_customer'.i18n();
        default:
          return status;
      }
    }
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
