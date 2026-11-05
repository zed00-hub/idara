import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static const String _dbName = 'ndmha_store.db';
  static const int _dbVersion = 1;

  static DBHelper? _instance;
  static Database? _database;

  DBHelper._internal();

  static DBHelper get instance {
    _instance ??= DBHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Enable FFI on desktop platforms (Windows, Linux, macOS)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, _dbName);

    // If database does not exist, copy pre-populated catalog from assets
    final bool exists = await databaseExists(path);
    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load('assets/database/products_catalog.db');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        // Fallback: If asset loading fails or in testing, standard creation will take place
      }
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        // Ensure all application tables exist even if copied from catalog
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Products Table (in case not already created from catalog)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        reference TEXT,
        cost_price REAL DEFAULT 0,
        retail_price REAL DEFAULT 0,
        wholesale_price REAL DEFAULT 0,
        quantity REAL DEFAULT 0,
        unit TEXT DEFAULT 'piece',
        category TEXT DEFAULT 'عام',
        is_custom INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');

    // 2. Customers Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        current_debt REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        notes TEXT
      )
    ''');

    // 3. Customer Debt Transactions (payments and added credit)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        invoice_id INTEGER,
        type TEXT NOT NULL, -- 'credit_sale', 'debt_payment'
        amount REAL NOT NULL,
        previous_debt REAL NOT NULL,
        new_debt REAL NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    // 4. Invoices Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        payment_type TEXT NOT NULL, -- 'cash', 'credit', 'partial'
        paid_amount REAL NOT NULL,
        remaining_debt REAL DEFAULT 0,
        change_given REAL DEFAULT 0,
        customer_id INTEGER,
        customer_name TEXT,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // 5. Invoice Items Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER,
        barcode TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        price_type TEXT DEFAULT 'retail',
        item_discount REAL DEFAULT 0,
        subtotal REAL NOT NULL,
        cost_price REAL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    // 6. Suppliers Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        company TEXT,
        current_debt REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        notes TEXT
      )
    ''');

    // 7. Supplier Purchase Invoices Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        supplier_name TEXT NOT NULL,
        invoice_number TEXT,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        remaining_debt REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE
      )
    ''');

    // 8. Expenses Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT DEFAULT 'أخرى',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        notes TEXT
      )
    ''');

    // 9. Cash Register (Drawer) Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_register (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opening_amount REAL NOT NULL,
        cash_in REAL DEFAULT 0,
        cash_out REAL DEFAULT 0,
        actual_closing_amount REAL,
        opened_at TEXT DEFAULT CURRENT_TIMESTAMP,
        closed_at TEXT,
        is_closed INTEGER DEFAULT 0,
        notes TEXT
      )
    ''');
  }

  /// Close and reset the database (useful for restoring backups)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
