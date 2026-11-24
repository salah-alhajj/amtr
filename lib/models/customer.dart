class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? notes;
  final String? preferences;
  final int returnCount;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.notes,
    this.preferences,
    this.returnCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// هل للعميل سوابق رفض أو إرجاع طلبات؟
  bool get hasRepeatRefusals => returnCount > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'notes': notes,
      'preferences': preferences,
      'returnCount': returnCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      notes: map['notes'] as String?,
      preferences: map['preferences'] as String?,
      returnCount: (map['returnCount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? notes,
    String? preferences,
    int? returnCount,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      notes: notes ?? this.notes,
      preferences: preferences ?? this.preferences,
      returnCount: returnCount ?? this.returnCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
