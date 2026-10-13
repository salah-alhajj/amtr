import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization/localization.dart';
import '../../../core/services/currency_service.dart';
import '../../../models/customer.dart';
import '../../../models/individual_order.dart';

enum CustomerOrderFilter {
  all,
  completedOnly,
  pendingOnly,
}

/// بيانات التسوية اليدوية للمركز المالي للعميل
class CustomerFinancialOverride {
  final double manualDebt;
  final double manualCredit;
  final double manualProfit;
  final bool isManualEnabled;
  final String? manualNotes;

  const CustomerFinancialOverride({
    this.manualDebt = 0.0,
    this.manualCredit = 0.0,
    this.manualProfit = 0.0,
    this.isManualEnabled = false,
    this.manualNotes,
  });

  bool get hasActiveOverride =>
      isManualEnabled &&
      (manualDebt > 0 || manualCredit > 0 || manualProfit > 0 || (manualNotes != null && manualNotes!.trim().isNotEmpty));

  CustomerFinancialOverride copyWith({
    double? manualDebt,
    double? manualCredit,
    double? manualProfit,
    bool? isManualEnabled,
    String? manualNotes,
  }) {
    return CustomerFinancialOverride(
      manualDebt: manualDebt ?? this.manualDebt,
      manualCredit: manualCredit ?? this.manualCredit,
      manualProfit: manualProfit ?? this.manualProfit,
      isManualEnabled: isManualEnabled ?? this.isManualEnabled,
      manualNotes: manualNotes ?? this.manualNotes,
    );
  }

  Map<String, dynamic> toMap() => {
        'manualDebt': manualDebt,
        'manualCredit': manualCredit,
        'manualProfit': manualProfit,
        'isManualEnabled': isManualEnabled,
        'manualNotes': manualNotes,
      };

  factory CustomerFinancialOverride.fromMap(Map<String, dynamic> map) => CustomerFinancialOverride(
        manualDebt: (map['manualDebt'] as num?)?.toDouble() ?? 0.0,
        manualCredit: (map['manualCredit'] as num?)?.toDouble() ?? 0.0,
        manualProfit: (map['manualProfit'] as num?)?.toDouble() ?? 0.0,
        isManualEnabled: map['isManualEnabled'] == true,
        manualNotes: map['manualNotes'] as String?,
      );
}

/// نتائج ومؤشرات الحالة المالية للعميل
class CustomerFinancialSummary {
  final double benefitedAmount; // المبالغ المستفادة منه (تختفي إذا كان صفر)
  final double debtsOwed; // المبالغ مديونياته لنا (تختفي إذا كان صفر)
  final double creditBalance; // المبالغ المتبقية له لدينا (تختفي إذا كان صفر)

  final double totalSales;
  final double totalCost;
  final double totalPaid;

  final int allOrdersCount;
  final int completedOrdersCount;
  final int pendingOrdersCount;
  final int debtsCount;

  final String activeCurrency;
  final CustomerFinancialOverride financialOverride;
  final CustomerOrderFilter appliedFilter;

  const CustomerFinancialSummary({
    required this.benefitedAmount,
    required this.debtsOwed,
    required this.creditBalance,
    required this.totalSales,
    required this.totalCost,
    required this.totalPaid,
    required this.allOrdersCount,
    required this.completedOrdersCount,
    required this.pendingOrdersCount,
    required this.debtsCount,
    required this.activeCurrency,
    required this.financialOverride,
    required this.appliedFilter,
  });

  /// هل تظهر بطاقة المبالغ المستفادة؟ (أخضر وتختفي إذا كان صفر)
  bool get showBenefited => benefitedAmount > 0.0001;

  /// هل تظهر بطاقة المديونيات؟ (أحمر وتختفي إذا كان صفر)
  bool get showDebt => debtsOwed > 0.0001;

  /// هل تظهر بطاقة المبالغ المتبقية له؟ (أزرق وتختفي إذا كان صفر)
  bool get showCredit => creditBalance > 0.0001;

  /// هل الحساب المالي متوازن بالكامل؟
  bool get isBalanced => !showBenefited && !showDebt && !showCredit;
}

class CustomerFinancialHelper {
  static const String _overrideTagPrefix = '<!--AMTR_FINANCIAL_OVERRIDE:';
  static const String _overrideTagSuffix = '-->';

  /// استخراج كائن التسوية اليدوية من حقل الملاحظات
  static CustomerFinancialOverride parseOverride(String? notes) {
    if (notes == null || notes.isEmpty) {
      return const CustomerFinancialOverride();
    }

    try {
      final startIndex = notes.indexOf(_overrideTagPrefix);
      if (startIndex != -1) {
        final endIndex = notes.indexOf(_overrideTagSuffix, startIndex);
        if (endIndex != -1) {
          final jsonStr = notes.substring(startIndex + _overrideTagPrefix.length, endIndex);
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return CustomerFinancialOverride.fromMap(map);
        }
      }
    } catch (_) {
      // إخفاق صامت والعودة للقيم الافتراضية
    }
    return const CustomerFinancialOverride();
  }

  /// تنظيف حقل الملاحظات لإظهار النص فقط للمستخدم في واجهات التعديل
  static String cleanUserNotes(String? notes) {
    if (notes == null || notes.isEmpty) return '';
    final startIndex = notes.indexOf(_overrideTagPrefix);
    if (startIndex == -1) return notes.trim();

    final endIndex = notes.indexOf(_overrideTagSuffix, startIndex);
    if (endIndex == -1) return notes.trim();

    final before = notes.substring(0, startIndex);
    final after = notes.substring(endIndex + _overrideTagSuffix.length);
    return '$before $after'.trim();
  }

  /// دمج ملاحظات المستخدم العادية مع كائن التسوية اليدوية لحفظها في SQLite
  static String encodeNotesWithOverride(String? cleanNotes, CustomerFinancialOverride override) {
    final cleaned = cleanUserNotes(cleanNotes);
    final jsonStr = jsonEncode(override.toMap());
    final tag = '$_overrideTagPrefix$jsonStr$_overrideTagSuffix';

    if (cleaned.isEmpty) {
      return tag;
    }
    return '$cleaned\n$tag';
  }

  /// احتساب الحالة المالية الفعلية للعميل وفق قواعد البزنس والألوان الثلاثة
  static CustomerFinancialSummary calculate({
    required Customer customer,
    required List<IndividualOrder> orders,
    required CurrencyService currencyService,
    CustomerOrderFilter filter = CustomerOrderFilter.all,
  }) {
    final activeCurrency = currencyService.activeDisplayCurrency;
    final override = parseOverride(customer.notes);

    int completedCount = 0;
    int pendingCount = 0;

    for (final o in orders) {
      if (o.orderStatus == AppConstants.orderStatusDelivered) {
        completedCount++;
      } else {
        pendingCount++;
      }
    }

    // تصفية الطلبات وفق النطاق المحدد
    final filteredOrders = orders.where((o) {
      switch (filter) {
        case CustomerOrderFilter.completedOnly:
          return o.orderStatus == AppConstants.orderStatusDelivered;
        case CustomerOrderFilter.pendingOnly:
          return o.orderStatus != AppConstants.orderStatusDelivered;
        case CustomerOrderFilter.all:
          return true;
      }
    }).toList();

    double totalSalesYer = 0.0;
    double totalCostYer = 0.0;
    double totalPaidYer = 0.0;
    double totalProfitYer = 0.0;
    double totalDebtYer = 0.0;
    double totalCreditYer = 0.0;
    int debtsCount = 0;

    for (final o in filteredOrders) {
      final sellYer = currencyService.toBaseYer(o.totalSellPrice, o.currency);
      final costYer = currencyService.toBaseYer(o.totalCostPrice, o.currency);
      final paidYer = currencyService.toBaseYer(o.paidAmount, o.currency);

      totalSalesYer += sellYer;
      totalCostYer += costYer;
      totalPaidYer += paidYer;

      // الأرباح المستفادة من الطلب
      final profit = sellYer - costYer;
      if (profit > 0) {
        totalProfitYer += profit;
      }

      // حساب المديونيات أو المبالغ المتبقية للعميل
      if (sellYer > paidYer) {
        totalDebtYer += (sellYer - paidYer);
        debtsCount++;
      } else if (paidYer > sellYer) {
        // العميل دفع زيادة عما عليه، فتكون لصالحه لدينا
        totalCreditYer += (paidYer - sellYer);
      }
    }

    // تطبيق التسوية اليدوية إذا كانت مفعلة
    if (override.isManualEnabled) {
      if (override.manualDebt > 0) {
        totalDebtYer += currencyService.toBaseYer(override.manualDebt, activeCurrency);
      }
      if (override.manualCredit > 0) {
        totalCreditYer += currencyService.toBaseYer(override.manualCredit, activeCurrency);
      }
      if (override.manualProfit > 0) {
        totalProfitYer += currencyService.toBaseYer(override.manualProfit, activeCurrency);
      }
    }

    // التحويل إلى العملة المعروضة النشطة
    final benefitedAmount = currencyService.fromBaseYer(totalProfitYer, activeCurrency);
    final debtsOwed = currencyService.fromBaseYer(totalDebtYer, activeCurrency);
    final creditBalance = currencyService.fromBaseYer(totalCreditYer, activeCurrency);

    final totalSales = currencyService.fromBaseYer(totalSalesYer, activeCurrency);
    final totalCost = currencyService.fromBaseYer(totalCostYer, activeCurrency);
    final totalPaid = currencyService.fromBaseYer(totalPaidYer, activeCurrency);

    return CustomerFinancialSummary(
      benefitedAmount: benefitedAmount,
      debtsOwed: debtsOwed,
      creditBalance: creditBalance,
      totalSales: totalSales,
      totalCost: totalCost,
      totalPaid: totalPaid,
      allOrdersCount: orders.length,
      completedOrdersCount: completedCount,
      pendingOrdersCount: pendingCount,
      debtsCount: debtsCount,
      activeCurrency: activeCurrency,
      financialOverride: override,
      appliedFilter: filter,
    );
  }

  /// التحقق من مطابقة العميل وملخصه المالي لفلتر محدد
  static bool matchesFilter({
    required Customer customer,
    required CustomerFinancialSummary? summary,
    required CustomerListFilter filter,
  }) {
    switch (filter) {
      case CustomerListFilter.all:
        return true;
      case CustomerListFilter.hasDebt:
        return summary != null && summary.debtsOwed > 0.001;
      case CustomerListFilter.isCreditor:
        return summary != null && summary.creditBalance > 0.001;
      case CustomerListFilter.hasPendingOrders:
        return summary != null && summary.pendingOrdersCount > 0;
      case CustomerListFilter.hasCompletedOrders:
        return summary != null && summary.completedOrdersCount > 0;
      case CustomerListFilter.noOrders:
        return summary == null || summary.allOrdersCount == 0;
      case CustomerListFilter.hasWhatsApp:
        return customer.whatsapp != null && customer.whatsapp!.trim().isNotEmpty;
    }
  }
}

/// أنواع الفلاتر لشاشة قائمة العملاء
enum CustomerListFilter {
  all,
  hasDebt,
  isCreditor,
  hasPendingOrders,
  hasCompletedOrders,
  noOrders,
  hasWhatsApp,
}

extension CustomerListFilterX on CustomerListFilter {
  String get translationKey {
    switch (this) {
      case CustomerListFilter.all:
        return 'customers_filter_all';
      case CustomerListFilter.hasDebt:
        return 'customers_filter_has_debt';
      case CustomerListFilter.isCreditor:
        return 'customers_filter_is_creditor';
      case CustomerListFilter.hasPendingOrders:
        return 'customers_filter_pending_orders';
      case CustomerListFilter.hasCompletedOrders:
        return 'customers_filter_completed_orders';
      case CustomerListFilter.noOrders:
        return 'customers_filter_no_orders';
      case CustomerListFilter.hasWhatsApp:
        return 'customers_filter_has_whatsapp';
    }
  }

  String get labelAr {
    switch (this) {
      case CustomerListFilter.all:
        return 'كافة العملاء';
      case CustomerListFilter.hasDebt:
        return 'عليهم ديون';
      case CustomerListFilter.isCreditor:
        return 'لهم رصيد (دائن)';
      case CustomerListFilter.hasPendingOrders:
        return 'طلبات معلقة';
      case CustomerListFilter.hasCompletedOrders:
        return 'طلبات مكتملة';
      case CustomerListFilter.noOrders:
        return 'بدون طلبات';
      case CustomerListFilter.hasWhatsApp:
        return 'متاح واتساب';
    }
  }

  String get labelEn {
    switch (this) {
      case CustomerListFilter.all:
        return 'All Customers';
      case CustomerListFilter.hasDebt:
        return 'With Debts';
      case CustomerListFilter.isCreditor:
        return 'Creditors (Balance)';
      case CustomerListFilter.hasPendingOrders:
        return 'Pending Orders';
      case CustomerListFilter.hasCompletedOrders:
        return 'Completed Orders';
      case CustomerListFilter.noOrders:
        return 'No Orders';
      case CustomerListFilter.hasWhatsApp:
        return 'WhatsApp Available';
    }
  }

  /// إرجاع التسمية مع fallback فوري يضمن عدم ظهور المفتاح الخام أبداً
  String label(BuildContext context) {
    try {
      final translated = translationKey.i18n();
      if (translated.isNotEmpty && translated != translationKey) {
        return translated;
      }
    } catch (_) {}
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    return isArabic ? labelAr : labelEn;
  }

  IconData get icon {
    switch (this) {
      case CustomerListFilter.all:
        return Icons.people_alt_rounded;
      case CustomerListFilter.hasDebt:
        return Icons.trending_down_rounded;
      case CustomerListFilter.isCreditor:
        return Icons.account_balance_wallet_rounded;
      case CustomerListFilter.hasPendingOrders:
        return Icons.hourglass_top_rounded;
      case CustomerListFilter.hasCompletedOrders:
        return Icons.check_circle_rounded;
      case CustomerListFilter.noOrders:
        return Icons.person_outline_rounded;
      case CustomerListFilter.hasWhatsApp:
        return Icons.chat_bubble_rounded;
    }
  }

  Color get activeColor {
    switch (this) {
      case CustomerListFilter.all:
        return const Color(0xFF007AFF); // iOS System Blue
      case CustomerListFilter.hasDebt:
        return const Color(0xFFFF3B30); // iOS System Red
      case CustomerListFilter.isCreditor:
        return const Color(0xFF5856D6); // iOS System Indigo / Purple
      case CustomerListFilter.hasPendingOrders:
        return const Color(0xFFFF9500); // iOS System Orange
      case CustomerListFilter.hasCompletedOrders:
        return const Color(0xFF34C759); // iOS System Green
      case CustomerListFilter.noOrders:
        return const Color(0xFF8E8E93); // iOS System Gray
      case CustomerListFilter.hasWhatsApp:
        return const Color(0xFF25D366); // WhatsApp Brand Green
    }
  }
}

