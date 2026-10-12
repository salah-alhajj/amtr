import 'dart:convert';
import '../core/constants.dart';

class OrderItem {
  final String id;
  final String orderId;
  final String name;
  final String? description;
  final int quantity;
  final double costPrice; // السعر المطلوب به (سعر التكلفة)
  final double? sellPrice; // السعر الذي يتم تسعيره للعميل (الافتراضي فاضي / null)
  final String currency; // العملة الخاصة بالبند
  final List<String> photos; // مسارات الصور المرفقة

  OrderItem({
    required this.id,
    required this.orderId,
    required this.name,
    this.description,
    this.quantity = 1,
    required this.costPrice,
    this.sellPrice,
    this.currency = AppConstants.currencyYer,
    List<String>? photos,
  }) : photos = photos ?? [];

  /// إجمالي التكلفة لهذا البند (الكمية × سعر التكلفة)
  double get totalCost => costPrice * quantity;

  /// إجمالي سعر البيع لهذا البند (الكمية × سعر البيع للعميل) إذا تم تسعيره
  double? get totalSell => sellPrice != null ? (sellPrice! * quantity) : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'costPrice': costPrice,
      'sellPrice': sellPrice,
      'currency': currency,
      'photos': jsonEncode(photos),
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedPhotos = [];
    if (map['photos'] != null) {
      try {
        final decoded = jsonDecode(map['photos'] as String);
        if (decoded is List) {
          parsedPhotos = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return OrderItem(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (map['sellPrice'] as num?)?.toDouble(),
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      photos: parsedPhotos,
    );
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? name,
    String? description,
    int? quantity,
    double? costPrice,
    double? sellPrice,
    String? currency,
    List<String>? photos,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      currency: currency ?? this.currency,
      photos: photos ?? this.photos,
    );
  }
}
