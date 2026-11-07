import 'package:flutter/material.dart';
import '../core/database/db_helper.dart';
import '../models/supplier.dart';

class SupplierProvider extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  double get totalSupplierDebts {
    return _suppliers.fold(0.0, (sum, s) => sum + s.currentDebt);
  }

  Future<void> loadSuppliers() async {
    _isLoading = true;
    notifyListeners();

    final db = await DBHelper.instance.database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    _suppliers = maps.map((m) => Supplier.fromMap(m)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<Supplier?> addSupplier({
    required String name,
    String? phone,
    String? company,
    double initialDebt = 0.0,
    String? notes,
  }) async {
    final db = await DBHelper.instance.database;
    final supplier = Supplier(
      name: name.trim(),
      phone: phone?.trim(),
      company: company?.trim(),
      currentDebt: initialDebt,
      notes: notes?.trim(),
    );

    try {
      final id = await db.insert('suppliers', supplier.toMap());
      await loadSuppliers();
      return Supplier(
        id: id,
        name: supplier.name,
        phone: supplier.phone,
        company: supplier.company,
        currentDebt: supplier.currentDebt,
        notes: supplier.notes,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> recordSupplierInvoice({
    required int supplierId,
    required String supplierName,
    required double totalAmount,
    required double paidAmount,
    String? invoiceNumber,
    String? notes,
    String? imagePath,
  }) async {
    final db = await DBHelper.instance.database;
    final remaining = (totalAmount - paidAmount) > 0 ? (totalAmount - paidAmount) : 0.0;

    try {
      await db.transaction((txn) async {
        await txn.insert('supplier_invoices', {
          'supplier_id': supplierId,
          'supplier_name': supplierName,
          'invoice_number': invoiceNumber,
          'total_amount': totalAmount,
          'paid_amount': paidAmount,
          'remaining_debt': remaining,
          'image_path': imagePath,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (remaining > 0) {
          await txn.rawUpdate(
            'UPDATE suppliers SET current_debt = current_debt + ? WHERE id = ?',
            [remaining, supplierId],
          );
        }
      });

      await loadSuppliers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSupplierInvoices(int supplierId) async {
    final db = await DBHelper.instance.database;
    return await db.query(
      'supplier_invoices',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'created_at DESC',
    );
  }

  Future<bool> paySupplierDebt({
    required int supplierId,
    required double amount,
  }) async {
    final db = await DBHelper.instance.database;
    try {
      await db.rawUpdate(
        'UPDATE suppliers SET current_debt = CASE WHEN (current_debt - ?) > 0 THEN (current_debt - ?) ELSE 0 END WHERE id = ?',
        [amount, amount, supplierId],
      );
      await loadSuppliers();
      return true;
    } catch (e) {
      return false;
    }
  }
}
