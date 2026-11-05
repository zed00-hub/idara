class CashRegister {
  final int? id;
  final double openingAmount;
  final double cashIn;
  final double cashOut;
  final double? actualClosingAmount;
  final String openedAt;
  final String? closedAt;
  final bool isClosed;
  final String? notes;

  CashRegister({
    this.id,
    required this.openingAmount,
    this.cashIn = 0.0,
    this.cashOut = 0.0,
    this.actualClosingAmount,
    String? openedAt,
    this.closedAt,
    this.isClosed = false,
    this.notes,
  }) : openedAt = openedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'opening_amount': openingAmount,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'actual_closing_amount': actualClosingAmount,
      'opened_at': openedAt,
      'closed_at': closedAt,
      'is_closed': isClosed ? 1 : 0,
      'notes': notes,
    };
  }

  factory CashRegister.fromMap(Map<String, dynamic> map) {
    return CashRegister(
      id: map['id'] as int?,
      openingAmount: (map['opening_amount'] as num?)?.toDouble() ?? 0.0,
      cashIn: (map['cash_in'] as num?)?.toDouble() ?? 0.0,
      cashOut: (map['cash_out'] as num?)?.toDouble() ?? 0.0,
      actualClosingAmount: (map['actual_closing_amount'] as num?)?.toDouble(),
      openedAt: map['opened_at']?.toString() ?? DateTime.now().toIso8601String(),
      closedAt: map['closed_at']?.toString(),
      isClosed: (map['is_closed'] == 1 || map['is_closed'] == true),
      notes: map['notes']?.toString(),
    );
  }
}
