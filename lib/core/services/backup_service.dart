import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

class BackupService {
  /// Exports full database tables into a JSON backup file and shares it
  static Future<String?> exportFullBackup() async {
    try {
      final db = await DBHelper.instance.database;

      final products = await db.query('products');
      final customers = await db.query('customers');
      final customerTransactions = await db.query('customer_transactions');
      final invoices = await db.query('invoices');
      final invoiceItems = await db.query('invoice_items');
      final suppliers = await db.query('suppliers');
      final supplierInvoices = await db.query('supplier_invoices');
      final expenses = await db.query('expenses');
      final cashRegister = await db.query('cash_register');

      final Map<String, dynamic> backupData = {
        'version': 1,
        'app': 'Nadmha POS',
        'export_date': DateTime.now().toIso8601String(),
        'products': products,
        'customers': customers,
        'customer_transactions': customerTransactions,
        'invoices': invoices,
        'invoice_items': invoiceItems,
        'suppliers': suppliers,
        'supplier_invoices': supplierInvoices,
        'expenses': expenses,
        'cash_register': cashRegister,
      };

      final jsonString = jsonEncode(backupData);

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = p.join(tempDir.path, 'nadmha_backup_$dateStr.json');
      final file = File(filePath);
      await file.writeAsString(jsonString, flush: true);

      // Share file
      await Share.shareXFiles([XFile(filePath)], text: 'نسخة احتياطية لتطبيق نظمها - $dateStr');
      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Restores database from a selected JSON backup file
  static Future<bool> restoreFromBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (data['app'] != 'Nadmha POS') {
        return false;
      }

      final db = await DBHelper.instance.database;
      await db.transaction((txn) async {
        // Clear tables
        await txn.delete('invoice_items');
        await txn.delete('invoices');
        await txn.delete('customer_transactions');
        await txn.delete('customers');
        await txn.delete('supplier_invoices');
        await txn.delete('suppliers');
        await txn.delete('expenses');
        await txn.delete('cash_register');

        // Restore Customers
        if (data['customers'] is List) {
          for (var item in data['customers']) {
            await txn.insert('customers', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Invoices
        if (data['invoices'] is List) {
          for (var item in data['invoices']) {
            await txn.insert('invoices', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Invoice Items
        if (data['invoice_items'] is List) {
          for (var item in data['invoice_items']) {
            await txn.insert('invoice_items', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Custom Products
        if (data['products'] is List) {
          for (var item in data['products']) {
            await txn.insert('products', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Customers Transactions
        if (data['customer_transactions'] is List) {
          for (var item in data['customer_transactions']) {
            await txn.insert('customer_transactions', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Suppliers
        if (data['suppliers'] is List) {
          for (var item in data['suppliers']) {
            await txn.insert('suppliers', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Expenses
        if (data['expenses'] is List) {
          for (var item in data['expenses']) {
            await txn.insert('expenses', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore Cash Register
        if (data['cash_register'] is List) {
          for (var item in data['cash_register']) {
            await txn.insert('cash_register', Map<String, dynamic>.from(item),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Exports products catalog as CSV file
  static Future<String?> exportProductsCsv() async {
    try {
      final db = await DBHelper.instance.database;
      final products = await db.query('products', orderBy: 'id ASC');

      final buffer = StringBuffer();
      // CSV BOM for Arabic encoding in Excel
      buffer.write('\uFEFF');
      buffer.writeln('الباركود,الاسم,المرجع,سعر التكلفة,سعر التجزئة,سعر الجملة,الكمية,الوحدة,الفئة');

      for (var p in products) {
        final barcode = p['barcode'] ?? '';
        final name = (p['name']?.toString() ?? '').replaceAll(',', ' ');
        final ref = (p['reference']?.toString() ?? '').replaceAll(',', ' ');
        final cost = p['cost_price'] ?? 0;
        final retail = p['retail_price'] ?? 0;
        final wholesale = p['wholesale_price'] ?? 0;
        final qty = p['quantity'] ?? 0;
        final unit = p['unit'] ?? 'piece';
        final cat = p['category'] ?? 'عام';

        buffer.writeln('$barcode,$name,$ref,$cost,$retail,$wholesale,$qty,$unit,$cat');
      }

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = p.join(tempDir.path, 'nadmha_products_$dateStr.csv');
      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8, flush: true);

      await Share.shareXFiles([XFile(filePath)], text: 'جرد السلع - تطبيق نظمها');
      return filePath;
    } catch (e) {
      return null;
    }
  }
}
