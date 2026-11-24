import '../core/constants.dart';

/// نموذج دفعة إنتاج لمنتج مصنّع لتتبع الكميات المنتجة وتكلفة الدفعة وتاريخ الإنتاج
class ProductionBatch {
  final String id;
  final String productId;
  final String productName;
  final int yieldCount;
  final double totalCost;
  final String currency;
  final String? notes;
  final DateTime producedAt;
  final String batchStatus; // curing | ready | expired
  final DateTime? readyAt;
  final DateTime? expiresAt;

  ProductionBatch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.yieldCount,
    this.totalCost = 0.0,
    this.currency = AppConstants.currencyYer,
    this.notes,
    DateTime? producedAt,
    this.batchStatus = AppConstants.batchStatusReady,
    this.readyAt,
    this.expiresAt,
  }) : producedAt = producedAt ?? DateTime.now();

  double get unitCost => yieldCount > 0 ? totalCost / yieldCount : 0.0;

  bool get isCuring => batchStatus == AppConstants.batchStatusCuring;
  bool get isReady => batchStatus == AppConstants.batchStatusReady;

  /// عدد الأيام المتبقية حتى جهوزية دفعة قيد التعتيق/التخمير
  int get daysUntilReady {
    if (!isCuring || readyAt == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(readyAt!.year, readyAt!.month, readyAt!.day);
    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  /// هل صلاحية الدفعة قريبة من الانتهاء (خلال 7 أيام قادمة)؟
  bool get isExpiringSoon {
    if (expiresAt == null || batchStatus == AppConstants.batchStatusExpired) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day);
    final daysLeft = expiry.difference(today).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'yieldCount': yieldCount,
      'totalCost': totalCost,
      'currency': currency,
      'notes': notes,
      'producedAt': producedAt.toIso8601String(),
      'batchStatus': batchStatus,
      'readyAt': readyAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory ProductionBatch.fromMap(Map<String, dynamic> map) {
    return ProductionBatch(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: (map['productName'] as String?) ?? '',
      yieldCount: (map['yieldCount'] as num?)?.toInt() ?? 0,
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      notes: map['notes'] as String?,
      producedAt: map['producedAt'] != null
          ? DateTime.parse(map['producedAt'] as String)
          : DateTime.now(),
      batchStatus:
          (map['batchStatus'] as String?) ?? AppConstants.batchStatusReady,
      readyAt: map['readyAt'] != null
          ? DateTime.parse(map['readyAt'] as String)
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
    );
  }

  ProductionBatch copyWith({
    String? id,
    String? productId,
    String? productName,
    int? yieldCount,
    double? totalCost,
    String? currency,
    String? notes,
    DateTime? producedAt,
    String? batchStatus,
    DateTime? readyAt,
    bool clearReadyAt = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return ProductionBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      yieldCount: yieldCount ?? this.yieldCount,
      totalCost: totalCost ?? this.totalCost,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      producedAt: producedAt ?? this.producedAt,
      batchStatus: batchStatus ?? this.batchStatus,
      readyAt: clearReadyAt ? null : (readyAt ?? this.readyAt),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    );
  }
}
