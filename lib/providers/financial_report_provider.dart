import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/db_helper.dart';
import '../models/cash_register.dart';
import '../models/expense.dart';

class ZReportSummary {
  final String date;
  final int totalInvoices;
  final double totalSales;
  final double cashSales;
  final double creditSales;
  final double totalDiscounts;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double openingCash;
  final double expectedDrawerCash;
  final double debtsCollected;

  ZReportSummary({
    required this.date,
    required this.totalInvoices,
    required this.totalSales,
    required this.cashSales,
    required this.creditSales,
    required this.totalDiscounts,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.openingCash,
    required this.expectedDrawerCash,
    required this.debtsCollected,
  });
}

class FinancialReportProvider extends ChangeNotifier {
  CashRegister? _activeRegister;
  List<Expense> _expenses = [];
  bool _isLoading = false;

  CashRegister? get activeRegister => _activeRegister;
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  /// Loads current active cash register for today
  Future<void> loadCurrentRegister() async {
    final db = await DBHelper.instance.database;
    final maps = await db.query(
      'cash_register',
      where: 'is_closed = 0',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      _activeRegister = CashRegister.fromMap(maps.first);
    } else {
      _activeRegister = null;
    }
    notifyListeners();
  }

  /// Open today's cash register with opening balance
  Future<void> openCashRegister(double openingAmount, {String? notes}) async {
    final db = await DBHelper.instance.database;
    final register = CashRegister(openingAmount: openingAmount, notes: notes);
    final id = await db.insert('cash_register', register.toMap());
    _activeRegister = CashRegister(
      id: id,
      openingAmount: register.openingAmount,
      openedAt: register.openedAt,
      notes: register.notes,
    );
    notifyListeners();
  }

  /// Record cash drawer movement (Cash-In or Cash-Out)
  Future<void> recordCashMovement({
    required double amount,
    required bool isCashIn,
    String? notes,
  }) async {
    if (_activeRegister == null || _activeRegister!.id == null) return;
    final db = await DBHelper.instance.database;

    if (isCashIn) {
      await db.rawUpdate(
        'UPDATE cash_register SET cash_in = cash_in + ? WHERE id = ?',
        [amount, _activeRegister!.id],
      );
    } else {
      await db.rawUpdate(
        'UPDATE cash_register SET cash_out = cash_out + ? WHERE id = ?',
        [amount, _activeRegister!.id],
      );
    }
    await loadCurrentRegister();
  }

  /// Close cash register
  Future<void> closeCashRegister(double actualAmount, {String? notes}) async {
    if (_activeRegister == null || _activeRegister!.id == null) return;
    final db = await DBHelper.instance.database;

    await db.update(
      'cash_register',
      {
        'actual_closing_amount': actualAmount,
        'closed_at': DateTime.now().toIso8601String(),
        'is_closed': 1,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [_activeRegister!.id],
    );

    _activeRegister = null;
    notifyListeners();
  }

  /// Load expenses for a date range (defaults to today)
  Future<void> loadExpenses({DateTime? date}) async {
    _isLoading = true;
    notifyListeners();

    final targetDate = date ?? DateTime.now();
    final dayStart = DateFormat('yyyy-MM-dd 00:00:00').format(targetDate);
    final dayEnd = DateFormat('yyyy-MM-dd 23:59:59').format(targetDate);

    final db = await DBHelper.instance.database;
    final maps = await db.query(
      'expenses',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [dayStart, dayEnd],
      orderBy: 'created_at DESC',
    );

    _expenses = maps.map((m) => Expense.fromMap(m)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addExpense({
    required String title,
    required double amount,
    String category = 'أخرى',
    String? notes,
  }) async {
    final db = await DBHelper.instance.database;
    final expense = Expense(
      title: title.trim(),
      amount: amount,
      category: category,
      notes: notes,
    );

    try {
      await db.insert('expenses', expense.toMap());
      // Also record as Cash-Out in register if open
      if (_activeRegister != null) {
        await recordCashMovement(amount: amount, isCashIn: false, notes: 'مصروف: $title');
      }
      await loadExpenses();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generates the Daily Z-Report
  Future<ZReportSummary> generateDailyZReport({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dayStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final dayStart = '$dayStr 00:00:00';
    final dayEnd = '$dayStr 23:59:59';

    final db = await DBHelper.instance.database;

    // 1. Invoices for the day
    final invoices = await db.query(
      'invoices',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [dayStart, dayEnd],
    );

    double totalSales = 0.0;
    double cashSales = 0.0;
    double creditSales = 0.0;
    double totalDiscounts = 0.0;

    for (var inv in invoices) {
      final total = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = (inv['remaining_debt'] as num?)?.toDouble() ?? 0.0;
      final disc = (inv['discount'] as num?)?.toDouble() ?? 0.0;

      totalSales += total;
      cashSales += paid;
      creditSales += remaining;
      totalDiscounts += disc;
    }

    // 2. Gross profit from items sold
    final invoiceItems = await db.rawQuery('''
      SELECT ii.quantity, ii.unit_price, ii.cost_price, ii.subtotal
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      WHERE i.created_at BETWEEN ? AND ?
    ''', [dayStart, dayEnd]);

    double totalCost = 0.0;
    for (var item in invoiceItems) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
      totalCost += (qty * cost);
    }
    final grossProfit = (totalSales - totalCost) > 0 ? (totalSales - totalCost) : 0.0;

    // 3. Expenses for the day
    final expMaps = await db.query(
      'expenses',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [dayStart, dayEnd],
    );
    double totalExpenses = expMaps.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));

    // 4. Debts collected today
    final debtMaps = await db.query(
      'customer_transactions',
      where: "type = 'debt_payment' AND created_at BETWEEN ? AND ?",
      whereArgs: [dayStart, dayEnd],
    );
    double debtsCollected = debtMaps.fold(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));

    // 5. Drawer Cash
    final opening = _activeRegister?.openingAmount ?? 0.0;
    final cashIn = _activeRegister?.cashIn ?? 0.0;
    final cashOut = _activeRegister?.cashOut ?? 0.0;
    final expectedDrawerCash = opening + cashSales + debtsCollected + cashIn - cashOut;

    final netProfit = grossProfit - totalExpenses;

    return ZReportSummary(
      date: dayStr,
      totalInvoices: invoices.length,
      totalSales: totalSales,
      cashSales: cashSales,
      creditSales: creditSales,
      totalDiscounts: totalDiscounts,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      openingCash: opening,
      expectedDrawerCash: expectedDrawerCash,
      debtsCollected: debtsCollected,
    );
  }
}
