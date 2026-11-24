import '../core/constants.dart';

/// نموذج مندوب التوصيل الداخلي أو المستقل
class Courier {
  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final double defaultFee;
  final String currency;
  final String? notes;
  final DateTime createdAt;

  Courier({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.defaultFee = 0.0,
    this.currency = AppConstants.currencyYer,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'defaultFee': defaultFee,
      'currency': currency,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Courier.fromMap(Map<String, dynamic> map) {
    return Courier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      defaultFee: (map['defaultFee'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Courier copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    double? defaultFee,
    String? currency,
    String? notes,
    DateTime? createdAt,
  }) {
    return Courier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      defaultFee: defaultFee ?? this.defaultFee,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
