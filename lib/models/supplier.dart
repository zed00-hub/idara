class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? company;
  final double currentDebt;
  final String? createdAt;
  final String? notes;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.company,
    this.currentDebt = 0.0,
    this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'company': company,
      'current_debt': currentDebt,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'notes': notes,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      company: map['company']?.toString(),
      currentDebt: (map['current_debt'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at']?.toString(),
      notes: map['notes']?.toString(),
    );
  }
}
