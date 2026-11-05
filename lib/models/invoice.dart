import 'cart_item.dart';

enum PaymentType { cash, credit, partial }

class Invoice {
  final int? id;
  final String invoiceNumber;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final PaymentType paymentType;
  final double paidAmount;
  final double remainingDebt;
  final double changeGiven;
  final int? customerId;
  final String? customerName;
  final String createdAt;
  final String? notes;
  final List<CartItem> items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.subtotal,
    this.discount = 0.0,
    required this.totalAmount,
    this.paymentType = PaymentType.cash,
    required this.paidAmount,
    this.remainingDebt = 0.0,
    this.changeGiven = 0.0,
    this.customerId,
    this.customerName,
    String? createdAt,
    this.notes,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'subtotal': subtotal,
      'discount': discount,
      'total_amount': totalAmount,
      'payment_type': paymentType.name,
      'paid_amount': paidAmount,
      'remaining_debt': remainingDebt,
      'change_given': changeGiven,
      'customer_id': customerId,
      'customer_name': customerName,
      'created_at': createdAt,
      'notes': notes,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {List<CartItem> items = const []}) {
    PaymentType pType = PaymentType.cash;
    if (map['payment_type'] == 'credit') {
      pType = PaymentType.credit;
    } else if (map['payment_type'] == 'partial') {
      pType = PaymentType.partial;
    }

    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: pType,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingDebt: (map['remaining_debt'] as num?)?.toDouble() ?? 0.0,
      changeGiven: (map['change_given'] as num?)?.toDouble() ?? 0.0,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name']?.toString(),
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      notes: map['notes']?.toString(),
      items: items,
    );
  }
}
