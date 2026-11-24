/// نموذج عنصر مكوّن داخل باقة أو بوكس هدايا (Product Bundle Item)
class ProductBundleItem {
  final String id;
  final String bundleProductId;
  final String componentProductId;
  final String componentName;
  final int quantity;

  const ProductBundleItem({
    required this.id,
    required this.bundleProductId,
    required this.componentProductId,
    required this.componentName,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bundleProductId': bundleProductId,
      'componentProductId': componentProductId,
      'componentName': componentName,
      'quantity': quantity,
    };
  }

  factory ProductBundleItem.fromMap(Map<String, dynamic> map) {
    return ProductBundleItem(
      id: map['id'] as String,
      bundleProductId: map['bundleProductId'] as String,
      componentProductId: map['componentProductId'] as String,
      componentName: (map['componentName'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  ProductBundleItem copyWith({
    String? id,
    String? bundleProductId,
    String? componentProductId,
    String? componentName,
    int? quantity,
  }) {
    return ProductBundleItem(
      id: id ?? this.id,
      bundleProductId: bundleProductId ?? this.bundleProductId,
      componentProductId: componentProductId ?? this.componentProductId,
      componentName: componentName ?? this.componentName,
      quantity: quantity ?? this.quantity,
    );
  }
}
