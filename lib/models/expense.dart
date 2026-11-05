class Expense {
  final int? id;
  final String title;
  final double amount;
  final String category; // rent, electricity, transport, salary, other
  final String createdAt;
  final String? notes;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    this.category = 'أخرى',
    String? createdAt,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'created_at': createdAt,
      'notes': notes,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category']?.toString() ?? 'أخرى',
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      notes: map['notes']?.toString(),
    );
  }
}
