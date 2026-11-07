import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/db_helper.dart';
import '../core/services/audio_service.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/product.dart';

class POSProvider extends ChangeNotifier {
  final List<CartItem> _cart = [];
  bool _isMultiScan = false;
  double _discount = 0.0;
  Customer? _selectedCustomer;
  PriceType _globalPriceType = PriceType.retail;

  // Multi-scan debounce tracker: barcode -> timestamp
  final Map<String, int> _recentlyScannedBarcodes = {};

  List<CartItem> get cart => _cart;
  bool get isMultiScan => _isMultiScan;
  double get discount => _discount;
  Customer? get selectedCustomer => _selectedCustomer;
  PriceType get globalPriceType => _globalPriceType;

  double get subtotal {
    return _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get netTotal {
    final net = subtotal - _discount;
    return net > 0 ? net : 0.0;
  }

  int get totalItemsCount {
    return _cart.fold(0, (sum, item) => sum + item.quantity.toInt());
  }

  void toggleMultiScan(bool value) {
    _isMultiScan = value;
    notifyListeners();
  }

  void setSelectedCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setGlobalPriceType(PriceType type) {
    _globalPriceType = type;
    for (var item in _cart) {
      item.switchPriceType(type);
    }
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount;
    notifyListeners();
  }

  /// Fetches product from SQLite database without adding it to cart automatically
  Future<Product?> getProductByBarcode(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) return null;
    final db = await DBHelper.instance.database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  /// Inserts or updates a product in SQLite and adds it to the active cart
  Future<Product> saveProductAndAddToCart({
    required Product product,
    double qty = 1.0,
  }) async {
    final db = await DBHelper.instance.database;
    Product finalProduct = product;
    if (product.id != null) {
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
    } else {
      final id = await db.insert('products', product.toMap());
      finalProduct = product.copyWith(id: id);
    }

    addToCart(finalProduct, qty: qty);
    AudioService.playScanBeep();
    return finalProduct;
  }

  /// Handles barcode scanned from camera
  Future<Product?> handleBarcodeScanned(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Debounce barcode scan (prevent firing 30 times a second for the same item in front of camera)
    if (_recentlyScannedBarcodes.containsKey(barcode)) {
      final lastScanned = _recentlyScannedBarcodes[barcode]!;
      if (now - lastScanned < (_isMultiScan ? 1200 : 1800)) {
        return null;
      }
    }
    _recentlyScannedBarcodes[barcode] = now;

    final db = await DBHelper.instance.database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    Product product;
    if (maps.isNotEmpty) {
      product = Product.fromMap(maps.first);
    } else {
      // Product not found in catalog, create placeholder so cashier can price it
      product = Product(
        barcode: barcode,
        name: 'منتج غير مسجل ($barcode)',
        retailPrice: 0.0,
        wholesalePrice: 0.0,
        isCustom: true,
      );
    }

    addToCart(product);
    AudioService.playScanBeep();
    return product;
  }

  void addToCart(Product product, {double qty = 1.0}) {
    final index = _cart.indexWhere((item) => item.product.barcode == product.barcode);
    if (index >= 0) {
      _cart[index].quantity += qty;
    } else {
      _cart.add(CartItem(
        product: product,
        quantity: qty,
        priceType: _globalPriceType,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(int index, double newQty) {
    if (index >= 0 && index < _cart.length) {
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = newQty;
      }
      notifyListeners();
    }
  }

  void updateItemPrice(int index, double newPrice) {
    if (index >= 0 && index < _cart.length) {
      _cart[index].unitPrice = newPrice;
      notifyListeners();
    }
  }

  void toggleItemPriceType(int index) {
    if (index >= 0 && index < _cart.length) {
      final item = _cart[index];
      final nextType = item.priceType == PriceType.retail ? PriceType.wholesale : PriceType.retail;
      item.switchPriceType(nextType);
      notifyListeners();
    }
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cart.length) {
      _cart.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    _discount = 0.0;
    _selectedCustomer = null;
    _recentlyScannedBarcodes.clear();
    notifyListeners();
  }

  /// Completes checkout and records invoice in SQLite
  Future<Invoice?> completeCheckout({
    required PaymentType paymentType,
    required double paidAmount,
    double changeGiven = 0.0,
    double remainingDebt = 0.0,
    String? notes,
  }) async {
    if (_cart.isEmpty) return null;

    final db = await DBHelper.instance.database;
    final dateStr = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final invoiceNumber = 'INV-$dateStr';

    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      subtotal: subtotal,
      discount: _discount,
      totalAmount: netTotal,
      paymentType: paymentType,
      paidAmount: paidAmount,
      remainingDebt: remainingDebt,
      changeGiven: changeGiven,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      notes: notes,
      items: List.from(_cart),
    );

    try {
      await db.transaction((txn) async {
        // 1. Insert Invoice
        final invoiceId = await txn.insert('invoices', invoice.toMap());

        // 2. Insert Invoice Items and decrement inventory
        for (var item in _cart) {
          await txn.insert('invoice_items', item.toMap(invoiceId: invoiceId));

          if (item.product.id != null) {
            await txn.rawUpdate(
              'UPDATE products SET quantity = quantity - ? WHERE id = ?',
              [item.quantity, item.product.id],
            );
          }
        }

        // 3. If credit or partial, record customer transaction & update debt
        if (remainingDebt > 0 && _selectedCustomer != null) {
          final currentDebt = _selectedCustomer!.currentDebt;
          final newDebt = currentDebt + remainingDebt;

          await txn.insert('customer_transactions', {
            'customer_id': _selectedCustomer!.id,
            'invoice_id': invoiceId,
            'type': 'credit_sale',
            'amount': remainingDebt,
            'previous_debt': currentDebt,
            'new_debt': newDebt,
            'notes': 'فاتورة $invoiceNumber',
            'created_at': DateTime.now().toIso8601String(),
          });

          await txn.update(
            'customers',
            {'current_debt': newDebt},
            where: 'id = ?',
            whereArgs: [_selectedCustomer!.id],
          );
        }
      });

      clearCart();
      return invoice;
    } catch (e) {
      return null;
    }
  }
}
