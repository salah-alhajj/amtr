import '../core/constants.dart';

/// نموذج منتج أو صنف في كتالوج الأسرة المنتجة أو البزنس الصغير
class Product {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double costPrice;
  final double sellPrice;
  final String currency;
  final int stockQuantity;
  final bool trackStock;
  final int lowStockThreshold;
  final bool isActive;
  final String? notes;
  final String? supplierId;
  final String productType; // resale | manufactured
  final int batchYield;
  final String? templateId;
  final int reorderCycleDays;
  final bool isBundle;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    this.category = 'cat_general',
    this.unit = 'حبة',
    this.costPrice = 0.0,
    required this.sellPrice,
    this.currency = AppConstants.currencyYer,
    this.stockQuantity = 0,
    this.trackStock = false,
    this.lowStockThreshold = 3,
    this.isActive = true,
    this.notes,
    this.supplierId,
    this.productType = AppConstants.productTypeResale,
    this.batchYield = 1,
    this.templateId,
    this.reorderCycleDays = 0,
    this.isBundle = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// هل المنتج تصنيعي/إنتاجي (له مواد خام وتكاليف إنتاج)؟
  bool get isManufactured => productType == AppConstants.productTypeManufactured;

  /// هل المنتج بيع وشراء (جاهز)؟
  bool get isResale => !isManufactured;

  /// الربح الصافي للوحدة الواحدة
  double get unitProfit => sellPrice - costPrice;

  /// هل المخزون منخفض أو نافد (فقط للمنتجات التي تتبع المخزون)
  bool get isLowStock => trackStock && stockQuantity <= lowStockThreshold;

  /// هل المنتج نافد من المخزون؟
  bool get isOutOfStock => trackStock && stockQuantity <= 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'costPrice': costPrice,
      'sellPrice': sellPrice,
      'currency': currency,
      'stockQuantity': stockQuantity,
      'trackStock': trackStock ? 1 : 0,
      'lowStockThreshold': lowStockThreshold,
      'isActive': isActive ? 1 : 0,
      'notes': notes,
      'supplierId': supplierId,
      'productType': productType,
      'batchYield': batchYield,
      'templateId': templateId,
      'reorderCycleDays': reorderCycleDays,
      'isBundle': isBundle ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'cat_general',
      unit: (map['unit'] as String?) ?? 'حبة',
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (map['sellPrice'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
      trackStock: (map['trackStock'] as num?)?.toInt() == 1,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 3,
      isActive: (map['isActive'] as num?)?.toInt() != 0,
      notes: map['notes'] as String?,
      supplierId: map['supplierId'] as String?,
      productType:
          (map['productType'] as String?) ?? AppConstants.productTypeResale,
      batchYield: (map['batchYield'] as num?)?.toInt() ?? 1,
      templateId: map['templateId'] as String?,
      reorderCycleDays: (map['reorderCycleDays'] as num?)?.toInt() ?? 0,
      isBundle: (map['isBundle'] as num?)?.toInt() == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    double? costPrice,
    double? sellPrice,
    String? currency,
    int? stockQuantity,
    bool? trackStock,
    int? lowStockThreshold,
    bool? isActive,
    String? notes,
    String? supplierId,
    bool clearSupplierId = false,
    String? productType,
    int? batchYield,
    String? templateId,
    bool clearTemplateId = false,
    int? reorderCycleDays,
    bool? isBundle,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      currency: currency ?? this.currency,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      trackStock: trackStock ?? this.trackStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      productType: productType ?? this.productType,
      batchYield: batchYield ?? this.batchYield,
      templateId: clearTemplateId ? null : (templateId ?? this.templateId),
      reorderCycleDays: reorderCycleDays ?? this.reorderCycleDays,
      isBundle: isBundle ?? this.isBundle,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
