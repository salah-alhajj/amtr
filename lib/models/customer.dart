class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? notes;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'notes': notes,
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
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
