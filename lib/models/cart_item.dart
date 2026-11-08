import 'product.dart';

enum PriceType { retail, wholesale }

class CartItem {
  final Product product;
  double quantity;
  double unitPrice;
  PriceType priceType;
  double itemDiscount;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    double? unitPrice,
    this.priceType = PriceType.retail,
    this.itemDiscount = 0.0,
  }) : unitPrice = unitPrice ??
            (priceType == PriceType.wholesale && product.wholesalePrice > 0
                ? product.wholesalePrice
                : product.retailPrice);

  double get subtotal {
    final raw = (quantity * unitPrice) - itemDiscount;
    return raw > 0 ? raw : 0.0;
  }

  double get totalCost => quantity * product.costPrice;
  double get profit => subtotal - totalCost;

  void switchPriceType(PriceType newType) {
    priceType = newType;
    if (newType == PriceType.wholesale && product.wholesalePrice > 0) {
      unitPrice = product.wholesalePrice;
    } else {
      unitPrice = product.retailPrice;
    }
  }

  Map<String, dynamic> toMap({int? invoiceId}) {
    return {
      'invoice_id': ?invoiceId,
      'product_id': product.id,
      'barcode': product.barcode,
      'product_name': product.name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'price_type': priceType == PriceType.wholesale ? 'wholesale' : 'retail',
      'item_discount': itemDiscount,
      'subtotal': subtotal,
      'cost_price': product.costPrice,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final product = Product(
      id: map['product_id'] as int?,
      barcode: map['barcode']?.toString() ?? '',
      name: map['product_name']?.toString() ?? '',
      retailPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
    );

    return CartItem(
      product: product,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      priceType: map['price_type'] == 'wholesale' ? PriceType.wholesale : PriceType.retail,
      itemDiscount: (map['item_discount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
