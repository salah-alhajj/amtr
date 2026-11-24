import '../core/constants.dart';

/// نموذج مادة خام أو مورد إنتاجي قابل لإعادة الاستخدام في وصفات التصنيع
class RawMaterial {
  final String id;
  final String name;
  final String unit;
  final double unitCost;
  final String currency;
  final String? supplierId;
  final String? notes;
  final double stockQuantity;
  final double lowStockThreshold;
  final DateTime createdAt;

  RawMaterial({
    required this.id,
    required this.name,
    this.unit = 'كجم',
    this.unitCost = 0.0,
    this.currency = AppConstants.currencyYer,
    this.supplierId,
    this.notes,
    this.stockQuantity = 0.0,
    this.lowStockThreshold = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isLowStock =>
      lowStockThreshold > 0 && stockQuantity <= lowStockThreshold;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'unitCost': unitCost,
      'currency': currency,
      'supplierId': supplierId,
      'notes': notes,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RawMaterial.fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: (map['unit'] as String?) ?? 'كجم',
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      supplierId: map['supplierId'] as String?,
      notes: map['notes'] as String?,
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  RawMaterial copyWith({
    String? id,
    String? name,
    String? unit,
    double? unitCost,
    String? currency,
    String? supplierId,
    bool clearSupplierId = false,
    String? notes,
    double? stockQuantity,
    double? lowStockThreshold,
    DateTime? createdAt,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      notes: notes ?? this.notes,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
