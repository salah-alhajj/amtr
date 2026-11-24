/// نموذج خيار/مقاس/نكهة فرعي لمنتج في الكتالوج (Product Variant)
class ProductVariant {
  final String id;
  final String productId;
  final String variantName;
  final String? sku;
  final double? costPrice;
  final double? sellPrice;
  final int stockQuantity;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.variantName,
    this.sku,
    this.costPrice,
    this.sellPrice,
    this.stockQuantity = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'variantName': variantName,
      'sku': sku,
      'costPrice': costPrice,
      'sellPrice': sellPrice,
      'stockQuantity': stockQuantity,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as String,
      productId: map['productId'] as String,
      variantName: (map['variantName'] as String?) ?? '',
      sku: map['sku'] as String?,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      sellPrice: (map['sellPrice'] as num?)?.toDouble(),
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
      isActive: (map['isActive'] as num?)?.toInt() != 0,
    );
  }

  ProductVariant copyWith({
    String? id,
    String? productId,
    String? variantName,
    String? sku,
    bool clearSku = false,
    double? costPrice,
    bool clearCostPrice = false,
    double? sellPrice,
    bool clearSellPrice = false,
    int? stockQuantity,
    bool? isActive,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantName: variantName ?? this.variantName,
      sku: clearSku ? null : (sku ?? this.sku),
      costPrice: clearCostPrice ? null : (costPrice ?? this.costPrice),
      sellPrice: clearSellPrice ? null : (sellPrice ?? this.sellPrice),
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
    );
  }
}
