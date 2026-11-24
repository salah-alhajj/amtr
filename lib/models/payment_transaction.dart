import '../core/constants.dart';

/// سجل حركة دفع نقدية/تحويل مؤرّخة لحساب الصندوق اليومي بدقة
class PaymentTransaction {
  final String id;
  final String? orderId;
  final String? customerId;
  final double amount;
  final String currency;
  final String paymentMethod; // cash | transfer
  final DateTime paidAt;
  final String? notes;

  PaymentTransaction({
    required this.id,
    this.orderId,
    this.customerId,
    required this.amount,
    this.currency = AppConstants.currencyYer,
    this.paymentMethod = AppConstants.paymentMethodCash,
    DateTime? paidAt,
    this.notes,
  }) : paidAt = paidAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'customerId': customerId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'paidAt': paidAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'] as String,
      orderId: map['orderId'] as String?,
      customerId: map['customerId'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      paymentMethod:
          (map['paymentMethod'] as String?) ?? AppConstants.paymentMethodCash,
      paidAt: map['paidAt'] != null
          ? DateTime.parse(map['paidAt'] as String)
          : DateTime.now(),
      notes: map['notes'] as String?,
    );
  }

  PaymentTransaction copyWith({
    String? id,
    String? orderId,
    String? customerId,
    double? amount,
    String? currency,
    String? paymentMethod,
    DateTime? paidAt,
    String? notes,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
    );
  }
}
