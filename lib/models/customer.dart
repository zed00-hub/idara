class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final double currentDebt;
  final String? createdAt;
  final String? notes;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.currentDebt = 0.0,
    this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'current_debt': currentDebt,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'notes': notes,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      address: map['address']?.toString(),
      currentDebt: (map['current_debt'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at']?.toString(),
      notes: map['notes']?.toString(),
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    double? currentDebt,
    String? createdAt,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      currentDebt: currentDebt ?? this.currentDebt,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          ((id != null && other.id != null && id == other.id) ||
              (id == null && other.id == null && name == other.name));

  @override
  int get hashCode => id?.hashCode ?? name.hashCode;
}
