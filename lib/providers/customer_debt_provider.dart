import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/database/db_helper.dart';
import '../core/services/storage_service.dart';
import '../core/utils/currency_formatter.dart';
import '../models/customer.dart';

class CustomerDebtProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  double get totalDebts {
    return _customers.fold(0.0, (sum, c) => c.currentDebt > 0 ? sum + c.currentDebt : sum);
  }

  double get totalAdvances {
    return _customers.fold(0.0, (sum, c) => c.currentDebt < 0 ? sum + (-c.currentDebt) : sum);
  }

  Future<void> loadCustomers({String query = ''}) async {
    _searchQuery = query.trim();
    _isLoading = true;
    notifyListeners();

    final db = await DBHelper.instance.database;
    List<Map<String, dynamic>> maps;

    if (_searchQuery.isEmpty) {
      maps = await db.query('customers', orderBy: 'current_debt DESC, name ASC');
    } else {
      maps = await db.query(
        'customers',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$_searchQuery%', '%$_searchQuery%'],
        orderBy: 'current_debt DESC, name ASC',
      );
    }

    _customers = maps.map((m) => Customer.fromMap(m)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<Customer?> addCustomer({
    required String name,
    String? phone,
    String? address,
    double initialDebt = 0.0,
    String? notes,
  }) async {
    final db = await DBHelper.instance.database;
    final customer = Customer(
      name: name.trim(),
      phone: phone?.trim(),
      address: address?.trim(),
      currentDebt: initialDebt,
      notes: notes?.trim(),
    );

    try {
      final id = await db.insert('customers', customer.toMap());
      if (initialDebt > 0) {
        await db.insert('customer_transactions', {
          'customer_id': id,
          'type': 'initial_balance',
          'amount': initialDebt,
          'previous_debt': 0,
          'new_debt': initialDebt,
          'notes': 'رصيد افتتاحي سابق',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await loadCustomers(query: _searchQuery);
      return customer.copyWith(id: id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    if (customer.id == null) return false;
    final db = await DBHelper.instance.database;
    try {
      await db.update(
        'customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );
      await loadCustomers(query: _searchQuery);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCustomer(int customerId) async {
    final db = await DBHelper.instance.database;
    try {
      await db.transaction((txn) async {
        await txn.delete('customer_transactions', where: 'customer_id = ?', whereArgs: [customerId]);
        await txn.delete('customers', where: 'id = ?', whereArgs: [customerId]);
      });
      await loadCustomers(query: _searchQuery);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Records a debt payment made by customer
  Future<bool> recordPayment({
    required int customerId,
    required double paymentAmount,
    String? notes,
  }) async {
    final db = await DBHelper.instance.database;
    try {
      final custMaps = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      if (custMaps.isEmpty) return false;

      final customer = Customer.fromMap(custMaps.first);
      final prevDebt = customer.currentDebt;
      // Allow negative debt which accurately denotes an advance / credit balance (تسبيق) in customer's favor
      final newDebt = prevDebt - paymentAmount;

      await db.transaction((txn) async {
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'type': 'debt_payment',
          'amount': paymentAmount,
          'previous_debt': prevDebt,
          'new_debt': newDebt,
          'notes': notes ?? 'تسديد دفعة نقداً',
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.update(
          'customers',
          {'current_debt': newDebt},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      });

      await loadCustomers(query: _searchQuery);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Refunds an advance credit (تسبيق) back to customer in cash and adjusts balance towards zero
  Future<bool> refundAdvance({
    required int customerId,
    required double refundAmount,
    String? notes,
  }) async {
    if (refundAmount <= 0) return false;
    final db = await DBHelper.instance.database;
    try {
      final custMaps = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      if (custMaps.isEmpty) return false;

      final customer = Customer.fromMap(custMaps.first);
      final prevDebt = customer.currentDebt;
      final newDebt = prevDebt + refundAmount;

      await db.transaction((txn) async {
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'type': 'advance_refund',
          'amount': refundAmount,
          'previous_debt': prevDebt,
          'new_debt': newDebt,
          'notes': notes ?? 'إرجاع تسبيق نقداً للزبون',
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.update(
          'customers',
          {'current_debt': newDebt},
          where: 'id = ?',
          whereArgs: [customerId],
        );

        // Record physical cash out from open drawer
        final openReg = await txn.query('cash_register', where: 'is_closed = 0', limit: 1);
        if (openReg.isNotEmpty) {
          final regId = openReg.first['id'] as int;
          await txn.rawUpdate(
            'UPDATE cash_register SET cash_out = cash_out + ? WHERE id = ?',
            [refundAmount, regId],
          );
        }
      });

      await loadCustomers(query: _searchQuery);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetches statement transactions for a specific customer
  Future<List<Map<String, dynamic>>> getCustomerTransactions(int customerId) async {
    final db = await DBHelper.instance.database;
    return await db.query(
      'customer_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  /// Share debt balance reminder to customer via WhatsApp
  static Future<void> sendDebtReminderWhatsApp(Customer customer) async {
    final storeName = StorageService.getStoreName();
    final storePhone = StorageService.getStorePhone();

    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله أخي الكريم *${customer.name}*،');
    buffer.writeln('تحية طيبة من *$storeName* 🏪');
    if (customer.currentDebt > 0) {
      buffer.writeln('نود تذكيركم بمستحقات الحساب الجاري لديكم:');
      buffer.writeln('💰 *المبلغ المستحق: ${CurrencyFormatter.format(customer.currentDebt)}*');
    } else if (customer.currentDebt < 0) {
      buffer.writeln('نحيطكم علماً برصيدكم الدائن المسبق في حسابكم لدينا:');
      buffer.writeln('💰 *الرصيد المتاح (تسبيق لصالحكم): ${CurrencyFormatter.format(-customer.currentDebt)}*');
    } else {
      buffer.writeln('نحيطكم علماً بأن حسابكم خالص تماماً ولا يوجد أي دين مسجل.');
    }
    buffer.writeln('📅 حتى تاريخ: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}');
    if (storePhone.isNotEmpty) buffer.writeln('📞 للاستفسار: $storePhone');
    buffer.writeln('بارك الله فيكم وشكراً لتعاملكم معنا!');

    await Share.share(buffer.toString(), subject: 'كشف حساب - $storeName');
  }
}
