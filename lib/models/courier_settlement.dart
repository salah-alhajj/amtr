/// نموذج سجل تسوية وتصفية حساب مندوب التوصيل
class CourierSettlement {
  final String id;
  final String courierId;
  final int orderCount;
  final double collectedCashYer;
  final double deliveryFeesYer;
  final double returnFeesYer;
  final double netRemittedYer;
  final String? notes;
  final DateTime settledAt;

  CourierSettlement({
    required this.id,
    required this.courierId,
    this.orderCount = 0,
    this.collectedCashYer = 0.0,
    this.deliveryFeesYer = 0.0,
    this.returnFeesYer = 0.0,
    this.netRemittedYer = 0.0,
    this.notes,
    DateTime? settledAt,
  }) : settledAt = settledAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courierId': courierId,
      'orderCount': orderCount,
      'collectedCashYer': collectedCashYer,
      'deliveryFeesYer': deliveryFeesYer,
      'returnFeesYer': returnFeesYer,
      'netRemittedYer': netRemittedYer,
      'notes': notes,
      'settledAt': settledAt.toIso8601String(),
    };
  }

  factory CourierSettlement.fromMap(Map<String, dynamic> map) {
    return CourierSettlement(
      id: map['id'] as String,
      courierId: map['courierId'] as String,
      orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
      collectedCashYer: (map['collectedCashYer'] as num?)?.toDouble() ?? 0.0,
      deliveryFeesYer: (map['deliveryFeesYer'] as num?)?.toDouble() ?? 0.0,
      returnFeesYer: (map['returnFeesYer'] as num?)?.toDouble() ?? 0.0,
      netRemittedYer: (map['netRemittedYer'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      settledAt: map['settledAt'] != null
          ? DateTime.parse(map['settledAt'] as String)
          : DateTime.now(),
    );
  }

  CourierSettlement copyWith({
    String? id,
    String? courierId,
    int? orderCount,
    double? collectedCashYer,
    double? deliveryFeesYer,
    double? returnFeesYer,
    double? netRemittedYer,
    String? notes,
    DateTime? settledAt,
  }) {
    return CourierSettlement(
      id: id ?? this.id,
      courierId: courierId ?? this.courierId,
      orderCount: orderCount ?? this.orderCount,
      collectedCashYer: collectedCashYer ?? this.collectedCashYer,
      deliveryFeesYer: deliveryFeesYer ?? this.deliveryFeesYer,
      returnFeesYer: returnFeesYer ?? this.returnFeesYer,
      netRemittedYer: netRemittedYer ?? this.netRemittedYer,
      notes: notes ?? this.notes,
      settledAt: settledAt ?? this.settledAt,
    );
  }
}
