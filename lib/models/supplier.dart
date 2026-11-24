/// نموذج المورد (تاجر جملة، مورد مواد خام، تغليف، خدمات...)
class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String category;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.category = 'sup_cat_general',
    this.address,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'category': category,
      'address': address,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      category: (map['category'] as String?) ?? 'sup_cat_general',
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? whatsapp,
    String? category,
    String? address,
    String? notes,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      category: category ?? this.category,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
