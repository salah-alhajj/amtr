/// سجل إغلاق يومي للصندوق (لقطة ختامية في 30 ثانية)
class DailyClosing {
  final String id;
  final String closingDate; // YYYY-MM-DD
  final double cashInYer;
  final double businessExpensesYer;
  final double personalDrawingsYer;
  final int ordersCount;
  final String? notes;
  final DateTime closedAt;

  DailyClosing({
    required this.id,
    required this.closingDate,
    required this.cashInYer,
    required this.businessExpensesYer,
    required this.personalDrawingsYer,
    this.ordersCount = 0,
    this.notes,
    DateTime? closedAt,
  }) : closedAt = closedAt ?? DateTime.now();

  double get netDrawerYer =>
      cashInYer - businessExpensesYer - personalDrawingsYer;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'closingDate': closingDate,
      'cashInYer': cashInYer,
      'businessExpensesYer': businessExpensesYer,
      'personalDrawingsYer': personalDrawingsYer,
      'ordersCount': ordersCount,
      'notes': notes,
      'closedAt': closedAt.toIso8601String(),
    };
  }

  factory DailyClosing.fromMap(Map<String, dynamic> map) {
    return DailyClosing(
      id: map['id'] as String,
      closingDate: map['closingDate'] as String,
      cashInYer: (map['cashInYer'] as num?)?.toDouble() ?? 0.0,
      businessExpensesYer:
          (map['businessExpensesYer'] as num?)?.toDouble() ?? 0.0,
      personalDrawingsYer:
          (map['personalDrawingsYer'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (map['ordersCount'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      closedAt: map['closedAt'] != null
          ? DateTime.parse(map['closedAt'] as String)
          : DateTime.now(),
    );
  }

  DailyClosing copyWith({
    String? id,
    String? closingDate,
    double? cashInYer,
    double? businessExpensesYer,
    double? personalDrawingsYer,
    int? ordersCount,
    String? notes,
    DateTime? closedAt,
  }) {
    return DailyClosing(
      id: id ?? this.id,
      closingDate: closingDate ?? this.closingDate,
      cashInYer: cashInYer ?? this.cashInYer,
      businessExpensesYer: businessExpensesYer ?? this.businessExpensesYer,
      personalDrawingsYer: personalDrawingsYer ?? this.personalDrawingsYer,
      ordersCount: ordersCount ?? this.ordersCount,
      notes: notes ?? this.notes,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
