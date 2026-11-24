import '../core/constants.dart';

/// نموذج حركة مالية في دفتر حساب المورد (شراء آجل، شراء نقدي، دفعة سداد)
class SupplierTransaction {
  final String id;
  final String supplierId;
  final String type; // purchase_credit | purchase_cash | payment
  final double amount;
  final String currency;
  final String? notes;
  final String? receiptPhotoPath;
  final DateTime txDate;
  final DateTime createdAt;

  SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.type,
    required this.amount,
    this.currency = AppConstants.currencyYer,
    this.notes,
    this.receiptPhotoPath,
    DateTime? txDate,
    DateTime? createdAt,
  })  : txDate = txDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isCreditPurchase => type == AppConstants.supplierTxPurchaseCredit;
  bool get isCashPurchase => type == AppConstants.supplierTxPurchaseCash;
  bool get isPayment => type == AppConstants.supplierTxPayment;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierId': supplierId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'notes': notes,
      'receiptPhotoPath': receiptPhotoPath,
      'txDate': txDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SupplierTransaction.fromMap(Map<String, dynamic> map) {
    return SupplierTransaction(
      id: map['id'] as String,
      supplierId: map['supplierId'] as String,
      type: (map['type'] as String?) ?? AppConstants.supplierTxPurchaseCredit,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      notes: map['notes'] as String?,
      receiptPhotoPath: map['receiptPhotoPath'] as String?,
      txDate: map['txDate'] != null
          ? DateTime.parse(map['txDate'] as String)
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  SupplierTransaction copyWith({
    String? id,
    String? supplierId,
    String? type,
    double? amount,
    String? currency,
    String? notes,
    bool clearNotes = false,
    String? receiptPhotoPath,
    bool clearReceiptPhotoPath = false,
    DateTime? txDate,
    DateTime? createdAt,
  }) {
    return SupplierTransaction(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      notes: clearNotes ? null : (notes ?? this.notes),
      receiptPhotoPath: clearReceiptPhotoPath
          ? null
          : (receiptPhotoPath ?? this.receiptPhotoPath),
      txDate: txDate ?? this.txDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
