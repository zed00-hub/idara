class Product {
  final int? id;
  final String barcode;
  final String name;
  final String? reference;
  final double costPrice;
  final double retailPrice;
  final double wholesalePrice;
  final double quantity;
  final String unit; // piece, kg, liter, box, bag, carton
  final String category;
  final bool isCustom; // 1 if added by merchant, 0 if from 42k preloaded catalog
  final String? createdAt;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.reference,
    this.costPrice = 0.0,
    this.retailPrice = 0.0,
    this.wholesalePrice = 0.0,
    this.quantity = 0.0,
    this.unit = 'piece',
    this.category = 'عام',
    this.isCustom = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barcode': barcode,
      'name': name,
      'reference': reference,
      'cost_price': costPrice,
      'retail_price': retailPrice,
      'wholesale_price': wholesalePrice,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'is_custom': isCustom ? 1 : 0,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      barcode: map['barcode']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      reference: map['reference']?.toString(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      retailPrice: (map['retail_price'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit']?.toString() ?? 'piece',
      category: map['category']?.toString() ?? 'عام',
      isCustom: (map['is_custom'] == 1 || map['is_custom'] == true),
      createdAt: map['created_at']?.toString(),
    );
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? reference,
    double? costPrice,
    double? retailPrice,
    double? wholesalePrice,
    double? quantity,
    String? unit,
    String? category,
    bool? isCustom,
    String? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      reference: reference ?? this.reference,
      costPrice: costPrice ?? this.costPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
