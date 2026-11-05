import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../models/product.dart';

class InventoryProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _currentQuery = '';
  String _selectedCategory = 'الكل';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  static const List<String> defaultCategories = [
    'الكل',
    'عام',
    'مواد غذائية',
    'مشروبات',
    'منظفات',
    'عطور وتجميل',
    'خضر وفواكه',
    'ألبان وأجبان',
    'حلويات وبسكويت',
  ];

  Future<void> searchProducts(String query) async {
    _currentQuery = query.trim();
    _isLoading = true;
    notifyListeners();

    final db = await DBHelper.instance.database;
    List<Map<String, dynamic>> maps;

    if (_currentQuery.isEmpty) {
      if (_selectedCategory == 'الكل') {
        maps = await db.query('products', orderBy: 'id DESC', limit: 60);
      } else {
        maps = await db.query(
          'products',
          where: 'category = ?',
          whereArgs: [_selectedCategory],
          orderBy: 'id DESC',
          limit: 60,
        );
      }
    } else {
      // First check if query is barcode
      if (_selectedCategory == 'الكل') {
        maps = await db.query(
          'products',
          where: 'barcode = ? OR name LIKE ?',
          whereArgs: [_currentQuery, '%$_currentQuery%'],
          orderBy: 'id DESC',
          limit: 60,
        );
      } else {
        maps = await db.query(
          'products',
          where: '(barcode = ? OR name LIKE ?) AND category = ?',
          whereArgs: [_currentQuery, '%$_currentQuery%', _selectedCategory],
          orderBy: 'id DESC',
          limit: 60,
        );
      }
    }

    _products = maps.map((m) => Product.fromMap(m)).toList();
    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    searchProducts(_currentQuery);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await DBHelper.instance.database;
    final cleanBarcode = barcode.trim();
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [cleanBarcode],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> addOrUpdateProduct(Product product) async {
    final db = await DBHelper.instance.database;
    try {
      if (product.id != null) {
        await db.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      } else {
        // Insert or replace by barcode
        await db.insert(
          'products',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await searchProducts(_currentQuery);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    final db = await DBHelper.instance.database;
    try {
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
      await searchProducts(_currentQuery);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Returns products with low stock (quantity <= 5) for shortage list
  Future<List<Product>> getLowStockProducts({double threshold = 5.0}) async {
    final db = await DBHelper.instance.database;
    final maps = await db.query(
      'products',
      where: 'quantity <= ?',
      whereArgs: [threshold],
      orderBy: 'quantity ASC',
      limit: 100,
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  /// Quick stock adjustment
  Future<void> adjustStock(int productId, double newQuantity) async {
    final db = await DBHelper.instance.database;
    await db.update(
      'products',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
    await searchProducts(_currentQuery);
  }
}
