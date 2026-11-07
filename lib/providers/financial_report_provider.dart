import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/db_helper.dart';
import '../models/cash_register.dart';
import '../models/expense.dart';

enum PeriodFilter { today, thisMonth, allTime }

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
  final double profitMarginPercent;

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
    this.profitMarginPercent = 0.0,
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

  Future<bool> deleteExpense(int id) async {
    final db = await DBHelper.instance.database;
    try {
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      await loadExpenses();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<double> getMonthExpensesTotal({DateTime? month}) async {
    final targetMonth = month ?? DateTime.now();
    final monthStart = DateFormat('yyyy-MM-01 00:00:00').format(targetMonth);
    final nextMonth = DateTime(targetMonth.year, targetMonth.month + 1, 1);
    final monthEnd = DateFormat('yyyy-MM-dd 00:00:00').format(nextMonth);

    final db = await DBHelper.instance.database;
    final res = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE created_at >= ? AND created_at < ?',
      [monthStart, monthEnd],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Generates the Daily Z-Report
  Future<ZReportSummary> generateDailyZReport({DateTime? date}) async {
    return generateReport(period: PeriodFilter.today, date: date);
  }

  /// Generates Financial Report with Period Filter (Today, This Month, All Time)
  Future<ZReportSummary> generateReport({
    PeriodFilter period = PeriodFilter.today,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final db = await DBHelper.instance.database;

    String? whereClause;
    List<dynamic>? whereArgs;
    String reportDateLabel;

    if (period == PeriodFilter.today) {
      final dayStr = DateFormat('yyyy-MM-dd').format(targetDate);
      whereClause = 'created_at BETWEEN ? AND ?';
      whereArgs = ['$dayStr 00:00:00', '$dayStr 23:59:59'];
      reportDateLabel = dayStr;
    } else if (period == PeriodFilter.thisMonth) {
      final monthStart = '${DateFormat("yyyy-MM").format(targetDate)}-01 00:00:00';
      final nextMonth = DateTime(targetDate.year, targetDate.month + 1, 1);
      final monthEnd = '${DateFormat("yyyy-MM-dd").format(nextMonth)} 00:00:00';
      whereClause = 'created_at >= ? AND created_at < ?';
      whereArgs = [monthStart, monthEnd];
      reportDateLabel = DateFormat('MMMM yyyy').format(targetDate);
    } else {
      whereClause = null;
      whereArgs = null;
      reportDateLabel = 'كافة الفترات (إجمالي)';
    }

    // 1. Invoices
    final invoices = await db.query(
      'invoices',
      where: whereClause,
      whereArgs: whereArgs,
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
    String itemsQuery = '''
      SELECT ii.quantity, ii.unit_price, ii.cost_price, ii.subtotal
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
    ''';
    if (whereClause != null) {
      itemsQuery += ' WHERE i.$whereClause';
    }
    final invoiceItems = await db.rawQuery(itemsQuery, whereArgs);

    double totalCost = 0.0;
    for (var item in invoiceItems) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
      totalCost += (qty * cost);
    }
    final grossProfit = totalSales - totalCost;

    // 3. Expenses
    final expMaps = await db.query(
      'expenses',
      where: whereClause,
      whereArgs: whereArgs,
    );
    double totalExpenses = expMaps.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));

    // 4. Debts collected
    String debtQuery = "type = 'debt_payment'";
    if (whereClause != null) {
      debtQuery += ' AND $whereClause';
    }
    final debtMaps = await db.query(
      'customer_transactions',
      where: debtQuery,
      whereArgs: whereArgs,
    );
    double debtsCollected = debtMaps.fold(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));

    // 5. Drawer Cash
    final opening = _activeRegister?.openingAmount ?? 0.0;
    final cashIn = _activeRegister?.cashIn ?? 0.0;
    final cashOut = _activeRegister?.cashOut ?? 0.0;
    final expectedDrawerCash = opening + cashSales + debtsCollected + cashIn - cashOut;

    final netProfit = grossProfit - totalExpenses;
    final profitMarginPercent = totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;

    return ZReportSummary(
      date: reportDateLabel,
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
      profitMarginPercent: profitMarginPercent,
    );
  }
}
