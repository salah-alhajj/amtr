import '../core/constants.dart';

/// بند تكلفة ضمن قالب تصنيع (مادة خام أو تكلفة إنتاجية أخرى: تغليف، عمالة، طاقة...)
class ManufacturingTemplateItem {
  final String id;
  final String templateId;
  final String itemType;
  final String? materialId;
  final String name;
  final double quantity;
  final String? unit;
  final double unitCost;
  final String currency;

  const ManufacturingTemplateItem({
    required this.id,
    required this.templateId,
    this.itemType = AppConstants.costItemMaterial,
    this.materialId,
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.unitCost = 0.0,
    this.currency = AppConstants.currencyYer,
  });

  double get totalCost => quantity * unitCost;
  bool get isMaterial => itemType == AppConstants.costItemMaterial;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'itemType': itemType,
      'materialId': materialId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitCost': unitCost,
      'currency': currency,
    };
  }

  factory ManufacturingTemplateItem.fromMap(Map<String, dynamic> map) {
    return ManufacturingTemplateItem(
      id: map['id'] as String,
      templateId: map['templateId'] as String,
      itemType: (map['itemType'] as String?) ?? AppConstants.costItemMaterial,
      materialId: map['materialId'] as String?,
      name: map['name'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String?,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
    );
  }

  ManufacturingTemplateItem copyWith({
    String? id,
    String? templateId,
    String? itemType,
    String? materialId,
    bool clearMaterialId = false,
    String? name,
    double? quantity,
    String? unit,
    double? unitCost,
    String? currency,
  }) {
    return ManufacturingTemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      itemType: itemType ?? this.itemType,
      materialId: clearMaterialId ? null : (materialId ?? this.materialId),
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
    );
  }
}

/// قالب تصنيعي قابل لإعادة الاستخدام (يحتوي على المواد والمقادير والتكاليف الإنتاجية)
class ManufacturingTemplate {
  final String id;
  final String name;
  final String? description;
  final int yieldCount;
  final String currency;
  final List<ManufacturingTemplateItem> items;
  final DateTime createdAt;

  ManufacturingTemplate({
    required this.id,
    required this.name,
    this.description,
    this.yieldCount = 1,
    this.currency = AppConstants.currencyYer,
    this.items = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get materialsCost => items
      .where((i) => i.isMaterial)
      .fold(0.0, (sum, i) => sum + i.totalCost);

  double get overheadCost => items
      .where((i) => !i.isMaterial)
      .fold(0.0, (sum, i) => sum + i.totalCost);

  double get totalBatchCost => materialsCost + overheadCost;

  double get unitCost =>
      yieldCount > 0 ? totalBatchCost / yieldCount : totalBatchCost;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'yieldCount': yieldCount,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ManufacturingTemplate.fromMap(
    Map<String, dynamic> map, {
    List<ManufacturingTemplateItem> items = const [],
  }) {
    return ManufacturingTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      yieldCount: (map['yieldCount'] as num?)?.toInt() ?? 1,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      items: items,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  ManufacturingTemplate copyWith({
    String? id,
    String? name,
    String? description,
    int? yieldCount,
    String? currency,
    List<ManufacturingTemplateItem>? items,
    DateTime? createdAt,
  }) {
    return ManufacturingTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      yieldCount: yieldCount ?? this.yieldCount,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
