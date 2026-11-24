import '../core/constants.dart';

/// مكوّن أو مادة خام أو بند تكلفة إنتاجية ضمن وصفة منتج لحساب تكلفة الوحدة بدقة
class ProductIngredient {
  final String id;
  final String productId;
  final String name;
  final double cost;
  final String currency;
  final int yieldCount;
  final String itemType;
  final String? materialId;
  final double quantity;
  final String? unit;
  final double unitCost;

  const ProductIngredient({
    required this.id,
    required this.productId,
    required this.name,
    required this.cost,
    this.currency = AppConstants.currencyYer,
    this.yieldCount = 1,
    this.itemType = AppConstants.costItemMaterial,
    this.materialId,
    this.quantity = 1.0,
    this.unit,
    this.unitCost = 0.0,
  });

  double get effectiveCost => cost > 0 ? cost : (quantity * unitCost);
  bool get isMaterial => itemType == AppConstants.costItemMaterial;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'cost': cost,
      'currency': currency,
      'yieldCount': yieldCount,
      'itemType': itemType,
      'materialId': materialId,
      'quantity': quantity,
      'unit': unit,
      'unitCost': unitCost,
    };
  }

  factory ProductIngredient.fromMap(Map<String, dynamic> map) {
    final cost = (map['cost'] as num?)?.toDouble() ?? 0.0;
    final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
    final uCost = (map['unitCost'] as num?)?.toDouble();
    return ProductIngredient(
      id: map['id'] as String,
      productId: map['productId'] as String,
      name: map['name'] as String,
      cost: cost,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      yieldCount: (map['yieldCount'] as num?)?.toInt() ?? 1,
      itemType: (map['itemType'] as String?) ?? AppConstants.costItemMaterial,
      materialId: map['materialId'] as String?,
      quantity: qty,
      unit: map['unit'] as String?,
      unitCost: uCost ?? (qty > 0 ? cost / qty : cost),
    );
  }

  ProductIngredient copyWith({
    String? id,
    String? productId,
    String? name,
    double? cost,
    String? currency,
    int? yieldCount,
    String? itemType,
    String? materialId,
    bool clearMaterialId = false,
    double? quantity,
    String? unit,
    double? unitCost,
  }) {
    return ProductIngredient(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      yieldCount: yieldCount ?? this.yieldCount,
      itemType: itemType ?? this.itemType,
      materialId: clearMaterialId ? null : (materialId ?? this.materialId),
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}
