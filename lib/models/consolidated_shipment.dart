import '../core/constants.dart';
import '../core/services/currency_service.dart';
import 'individual_order.dart';

class ConsolidatedShipment {
  final String id;
  final String shipmentNumber;
  final String title;
  final String? carrierName;
  final String? trackingNumber;
  final double transportCost; // تكلفة النقل
  final String transportCostCurrency; // عملة سداد تكلفة النقل
  final String status; // dispatched, checkpoint_reached, distribution_ready
  final DateTime createdAt;
  final DateTime? expectedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final String? notes;
  final List<IndividualOrder> orders;

  ConsolidatedShipment({
    required this.id,
    required this.shipmentNumber,
    required this.title,
    this.carrierName,
    this.trackingNumber,
    this.transportCost = 0.0,
    this.transportCostCurrency = AppConstants.currencyYer,
    this.status = AppConstants.shipmentDispatched,
    DateTime? createdAt,
    this.expectedDeliveryDate,
    this.actualDeliveryDate,
    this.notes,
    List<IndividualOrder>? orders,
  })  : createdAt = createdAt ?? DateTime.now(),
        orders = orders ?? [];

  /// حساب إجمالي سعر الشراء الأصلي للطلبات المجمعة بالإضافة إلى التكاليف الإضافية (بالريال اليمني)
  double calculateTotalOriginalCostInYer([CurrencyService? service]) {
    final currencyService = service ?? CurrencyService.instance;
    double totalYer = 0.0;
    for (final order in orders) {
      if (order.additionalCost > 0) {
        totalYer += currencyService.toBaseYer(order.additionalCost, order.currency);
      }
      for (final item in order.items) {
        totalYer += currencyService.toBaseYer(item.totalCost, item.currency);
      }
    }
    return totalYer;
  }

  /// حساب إجمالي سعر البيع المسعر للعملاء (بالريال اليمني)
  double calculateTotalClientSellPriceInYer([CurrencyService? service]) {
    final currencyService = service ?? CurrencyService.instance;
    double totalYer = 0.0;
    for (final order in orders) {
      for (final item in order.items) {
        if (item.sellPrice != null) {
          totalYer += currencyService.toBaseYer(item.totalSell!, item.currency);
        }
      }
    }
    return totalYer;
  }

  /// تكلفة النقل محولة إلى الريال اليمني
  double calculateTransportCostInYer([CurrencyService? service]) {
    final currencyService = service ?? CurrencyService.instance;
    return currencyService.toBaseYer(transportCost, transportCostCurrency);
  }

  /// صافي الربح الحقيقي من الشحنة المجمعة:
  /// (إجمالي سعر البيع للعملاء) - (إجمالي سعر شراء البضاعة) - (تكلفة النقل)
  double calculateNetProfitInYer([CurrencyService? service]) {
    final sellYer = calculateTotalClientSellPriceInYer(service);
    final costYer = calculateTotalOriginalCostInYer(service);
    final transportYer = calculateTransportCostInYer(service);
    return sellYer - costYer - transportYer;
  }

  /// احتساب الربح الصافي بأي عملة مختارة (YER, SAR, USD)
  double calculateNetProfitIn({required String targetCurrency, CurrencyService? service}) {
    final currencyService = service ?? CurrencyService.instance;
    final profitYer = calculateNetProfitInYer(currencyService);
    return currencyService.fromBaseYer(profitYer, targetCurrency);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shipmentNumber': shipmentNumber,
      'title': title,
      'carrierName': carrierName,
      'trackingNumber': trackingNumber,
      'transportCost': transportCost,
      'transportCostCurrency': transportCostCurrency,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
      'actualDeliveryDate': actualDeliveryDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory ConsolidatedShipment.fromMap(
    Map<String, dynamic> map, {
    List<IndividualOrder> orders = const [],
  }) {
    return ConsolidatedShipment(
      id: map['id'] as String,
      shipmentNumber: map['shipmentNumber'] as String,
      title: map['title'] as String,
      carrierName: map['carrierName'] as String?,
      trackingNumber: map['trackingNumber'] as String?,
      transportCost: (map['transportCost'] as num?)?.toDouble() ?? 0.0,
      transportCostCurrency:
          (map['transportCostCurrency'] as String?) ?? AppConstants.currencyYer,
      status: (map['status'] as String?) ?? AppConstants.shipmentDispatched,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      expectedDeliveryDate: map['expectedDeliveryDate'] != null
          ? DateTime.parse(map['expectedDeliveryDate'] as String)
          : null,
      actualDeliveryDate: map['actualDeliveryDate'] != null
          ? DateTime.parse(map['actualDeliveryDate'] as String)
          : null,
      notes: map['notes'] as String?,
      orders: orders,
    );
  }

  ConsolidatedShipment copyWith({
    String? id,
    String? shipmentNumber,
    String? title,
    String? carrierName,
    String? trackingNumber,
    double? transportCost,
    String? transportCostCurrency,
    String? status,
    DateTime? createdAt,
    DateTime? expectedDeliveryDate,
    DateTime? actualDeliveryDate,
    String? notes,
    List<IndividualOrder>? orders,
  }) {
    return ConsolidatedShipment(
      id: id ?? this.id,
      shipmentNumber: shipmentNumber ?? this.shipmentNumber,
      title: title ?? this.title,
      carrierName: carrierName ?? this.carrierName,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      transportCost: transportCost ?? this.transportCost,
      transportCostCurrency: transportCostCurrency ?? this.transportCostCurrency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      notes: notes ?? this.notes,
      orders: orders ?? this.orders,
    );
  }
}
