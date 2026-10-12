import '../core/constants.dart';
import 'order_item.dart';

class IndividualOrder {
  final String id;
  final String orderNumber;
  final String? customerId;
  final String? customerName;
  final String? shipmentId;
  final String paymentStatus; // prepaid, debt, cod, partial
  final String orderStatus; // pending, purchased, in_cargo, ready, delivered
  final DateTime createdAt;
  final DateTime? expectedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final DateTime? debtDueDate;
  final bool hasDebtReminder;
  final bool isSyncedWithCalendar;
  final double paidAmount;
  final String currency;
  final double additionalCost;
  final String? notes;
  final List<OrderItem> items;

  IndividualOrder({
    required this.id,
    required this.orderNumber,
    this.customerId,
    this.customerName,
    this.shipmentId,
    this.paymentStatus = AppConstants.paymentDebt,
    this.orderStatus = AppConstants.orderStatusPending,
    DateTime? createdAt,
    this.expectedDeliveryDate,
    this.actualDeliveryDate,
    this.debtDueDate,
    this.hasDebtReminder = false,
    this.isSyncedWithCalendar = false,
    this.paidAmount = 0.0,
    this.additionalCost = 0.0,
    this.currency = AppConstants.currencyYer,
    this.notes,
    List<OrderItem>? items,
  })  : createdAt = createdAt ?? DateTime.now(),
        items = items ?? [];

  /// إجمالي سعر التكلفة الأصلي المطلوب به بالإضافة إلى التكلفة الإضافية للطلب
  double get totalCostPrice {
    double total = additionalCost;
    for (final item in items) {
      total += item.totalCost;
    }
    return total;
  }

  /// إجمالي تكلفة الأصناف والسلع وحدها دون المصاريف الإضافية
  double get itemsCostOnly {
    double total = 0.0;
    for (final item in items) {
      total += item.totalCost;
    }
    return total;
  }

  /// إجمالي سعر البيع المسعر للعميل (إذا كان فارغاً لبعض البنود يعود بما تم تسعيره)
  double get totalSellPrice {
    double total = 0.0;
    for (final item in items) {
      if (item.sellPrice != null) {
        total += item.totalSell!;
      }
    }
    return total;
  }

  /// هل تم تسعير جميع الأغراض للعميل؟
  bool get isFullyPriced {
    if (items.isEmpty) return false;
    return items.every((item) => item.sellPrice != null);
  }

  /// صافي الربح التقديري من الطلب الفردي (سعر البيع - إجمالي التكلفة الشاملة للإضافية)
  double get rawProfit => totalSellPrice - totalCostPrice;

  /// المبلغ المتبقي كدين على العميل
  double get remainingDebt {
    final remaining = totalSellPrice - paidAmount;
    return remaining > 0 ? remaining : 0.0;
  }

  /// هل الطلب مسدد بالكامل؟
  bool get isFullyPaid => totalSellPrice > 0 && paidAmount >= totalSellPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'shipmentId': shipmentId,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus,
      'createdAt': createdAt.toIso8601String(),
      'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
      'actualDeliveryDate': actualDeliveryDate?.toIso8601String(),
      'debtDueDate': debtDueDate?.toIso8601String(),
      'hasDebtReminder': hasDebtReminder ? 1 : 0,
      'isSyncedWithCalendar': isSyncedWithCalendar ? 1 : 0,
      'paidAmount': paidAmount,
      'additionalCost': additionalCost,
      'currency': currency,
      'notes': notes,
    };
  }

  factory IndividualOrder.fromMap(
    Map<String, dynamic> map, {
    List<OrderItem> items = const [],
  }) {
    return IndividualOrder(
      id: map['id'] as String,
      orderNumber: map['orderNumber'] as String,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      shipmentId: map['shipmentId'] as String?,
      paymentStatus: (map['paymentStatus'] as String?) ?? AppConstants.paymentDebt,
      orderStatus: (map['orderStatus'] as String?) ?? AppConstants.orderStatusPending,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      expectedDeliveryDate: map['expectedDeliveryDate'] != null
          ? DateTime.parse(map['expectedDeliveryDate'] as String)
          : null,
      actualDeliveryDate: map['actualDeliveryDate'] != null
          ? DateTime.parse(map['actualDeliveryDate'] as String)
          : null,
      debtDueDate: map['debtDueDate'] != null
          ? DateTime.parse(map['debtDueDate'] as String)
          : null,
      hasDebtReminder: (map['hasDebtReminder'] as int?) == 1,
      isSyncedWithCalendar: (map['isSyncedWithCalendar'] as int?) == 1,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      additionalCost: (map['additionalCost'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      notes: map['notes'] as String?,
      items: items,
    );
  }

  IndividualOrder copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? shipmentId,
    String? paymentStatus,
    String? orderStatus,
    DateTime? createdAt,
    DateTime? expectedDeliveryDate,
    DateTime? actualDeliveryDate,
    DateTime? debtDueDate,
    bool? hasDebtReminder,
    bool? isSyncedWithCalendar,
    double? paidAmount,
    double? additionalCost,
    String? currency,
    String? notes,
    List<OrderItem>? items,
  }) {
    return IndividualOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      shipmentId: shipmentId ?? this.shipmentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderStatus: orderStatus ?? this.orderStatus,
      createdAt: createdAt ?? this.createdAt,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      debtDueDate: debtDueDate ?? this.debtDueDate,
      hasDebtReminder: hasDebtReminder ?? this.hasDebtReminder,
      isSyncedWithCalendar: isSyncedWithCalendar ?? this.isSyncedWithCalendar,
      paidAmount: paidAmount ?? this.paidAmount,
      additionalCost: additionalCost ?? this.additionalCost,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
}
