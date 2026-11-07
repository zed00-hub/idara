import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../pos/barcode_scanner_screen.dart';

/// Backward-compatible dialog launcher that pushes the modern full-screen ProductFormScreen
class ProductFormDialog {
  static Future<Product?> show(BuildContext context, {Product? product}) {
    return Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (ctx) => ProductFormScreen(product: product),
        fullscreenDialog: true,
      ),
    );
  }
}

/// Ultra-modern, spacious full-screen Product Form following global POS standards
class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _retailCtrl;
  late TextEditingController _wholesaleCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _minAlertCtrl;

  String _selectedCategory = 'عام';
  String _selectedUnit = 'piece';

  // Live profit calculation
  double _profitAmount = 0.0;
  double _profitMarginPercent = 0.0;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _costCtrl = TextEditingController(text: (p?.costPrice ?? 0) > 0 ? (p!.costPrice).round().toString() : '');
    _retailCtrl = TextEditingController(text: (p?.retailPrice ?? 0) > 0 ? (p!.retailPrice).round().toString() : '');
    _wholesaleCtrl = TextEditingController(text: (p?.wholesalePrice ?? 0) > 0 ? (p!.wholesalePrice).round().toString() : '');
    _qtyCtrl = TextEditingController(text: (p?.quantity ?? 100).toInt().toString());
    _minAlertCtrl = TextEditingController(text: '5');
    _selectedCategory = p?.category ?? 'عام';
    _selectedUnit = p?.unit ?? 'piece';

    _costCtrl.addListener(_updateProfitCalculation);
    _retailCtrl.addListener(_updateProfitCalculation);
    _updateProfitCalculation();
  }

  @override
  void dispose() {
    _costCtrl.removeListener(_updateProfitCalculation);
    _retailCtrl.removeListener(_updateProfitCalculation);
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _retailCtrl.dispose();
    _wholesaleCtrl.dispose();
    _qtyCtrl.dispose();
    _minAlertCtrl.dispose();
    super.dispose();
  }

  void _updateProfitCalculation() {
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final retail = double.tryParse(_retailCtrl.text.trim()) ?? 0.0;
    setState(() {
      _profitAmount = retail - cost;
      if (cost > 0) {
        _profitMarginPercent = ((retail - cost) / cost) * 100;
      } else {
        _profitMarginPercent = retail > 0 ? 100.0 : 0.0;
      }
    });
  }

  void _scanBarcodeWithCamera() async {
    final scannedBarcode = await BarcodeScannerScreen.scanBarcodeString(context);
    if (scannedBarcode != null && scannedBarcode.isNotEmpty && mounted) {
      setState(() {
        _barcodeCtrl.text = scannedBarcode;
      });
    }
  }

  void _generateAutomaticBarcode() {
    // Generates a valid standard 12-digit internal in-store code
    final randomSuffix = (Random().nextInt(89999999) + 10000000).toString();
    final generated = '20$randomSuffix';
    setState(() {
      _barcodeCtrl.text = generated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ تم توليد باركود محلي داخلي بنجاح: $generated'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addQuickStock(double delta) {
    final current = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final updated = (current + delta).clamp(0, 99999).toDouble();
    setState(() {
      _qtyCtrl.text = updated.toInt().toString();
    });
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى التأكد من ملء الحقول المطلوبة الإلزامية (*)'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final barcode = _barcodeCtrl.text.trim();
    final db = await DBHelper.instance.database;

    // Check for duplicate barcode
    final existing = await db.query(
      'products',
      where: 'barcode = ? AND (id != ? OR ? IS NULL)',
      whereArgs: [barcode, widget.product?.id ?? -1, widget.product?.id],
      limit: 1,
    );

    if (existing.isNotEmpty && mounted) {
      final existingName = existing.first['name'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ هذا الباركود ($barcode) مسجل مسبقاً لسلعة: $existingName'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final retail = double.tryParse(_retailCtrl.text.trim()) ?? 0.0;
    final wholesale = double.tryParse(_wholesaleCtrl.text.trim()) ?? retail;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;

    final updatedProduct = Product(
      id: widget.product?.id,
      barcode: barcode,
      name: _nameCtrl.text.trim(),
      costPrice: cost,
      retailPrice: retail,
      wholesalePrice: wholesale > 0 ? wholesale : retail,
      quantity: qty,
      unit: _selectedUnit,
      category: _selectedCategory,
      isCustom: true,
    );

    if (mounted) {
      Navigator.of(context).pop(updatedProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorderColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardBgColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'إلغاء والرجوع',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'تعديل بيانات السلعة' : 'إضافة سلعة جديدة للمخزون',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _saveProduct,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // -------------------------------------------------------------
              // بطاقة 1: معلومات التعريف وهوية السلعة (Product Identity)
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryIndigo.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryIndigo, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'المعلومات الأساسية والتعريف',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // اسم السلعة
                    TextFormField(
                      controller: _nameCtrl,
                      autofocus: !isEditing,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'اسم السلعة / المنتج *',
                        hintText: 'مثال: علبة حليب كونديّا 1 لتر',
                        prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryIndigo),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال اسم السلعة' : null,
                    ),
                    const SizedBox(height: 14),

                    // الباركود مع زري المسح والتوليد
                    TextFormField(
                      controller: _barcodeCtrl,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'الباركود (كود السلعة) *',
                        hintText: 'امسح الباركود أو اكتبه',
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال أو مسح الباركود' : null,
                    ),
                    const SizedBox(height: 8),

                    // أزرار سريعة للباركود
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _scanBarcodeWithCamera,
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('مسح بالكاميرا', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _generateAutomaticBarcode,
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text('توليد رمز تلقائي', style: TextStyle(fontSize: 13)),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              backgroundColor: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // الفئة والوحدة
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'الفئة',
                              prefixIcon: const Icon(Icons.category_outlined, size: 20),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                            items: InventoryProvider.defaultCategories
                                .where((c) => c != 'الكل')
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val ?? 'عام'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            decoration: InputDecoration(
                              labelText: 'وحدة القياس',
                              prefixIcon: const Icon(Icons.straighten, size: 20),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'piece', child: Text('قطعة')),
                              DropdownMenuItem(value: 'kg', child: Text('كيلوغرام')),
                              DropdownMenuItem(value: 'liter', child: Text('لتر')),
                              DropdownMenuItem(value: 'box', child: Text('علبة')),
                              DropdownMenuItem(value: 'bag', child: Text('كيس')),
                              DropdownMenuItem(value: 'carton', child: Text('كرتونة')),
                            ],
                            onChanged: (val) => setState(() => _selectedUnit = val ?? 'piece'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // -------------------------------------------------------------
              // بطاقة 2: التسعير الذكي وحاسبة هامش الربح (Pricing & Live Profit)
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.retailColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.price_check, color: AppColors.retailColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'التسعير وهوامش الأرباح',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // سعر التجزئة وسعر الجملة
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _retailCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'سعر التجزئة (دج) *',
                              hintText: 'مثال: 150',
                              prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.retailColor),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'أدخل السعر';
                              final n = double.tryParse(val.trim());
                              if (n == null || n <= 0) return 'سعر غير صالح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _wholesaleCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'سعر الجملة (دج)',
                              hintText: 'اختياري',
                              prefixIcon: const Icon(Icons.storefront_outlined, color: AppColors.wholesaleColor),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // سعر الشراء / التكلفة
                    TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'سعر الشراء / التكلفة (دج) - اختياري',
                        hintText: 'يساعدك في حساب الأرباح الدقيقة',
                        prefixIcon: const Icon(Icons.receipt_long_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // مؤشر حساب هامش الربح الحي (Live Profit Margin Widget)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _profitAmount > 0
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : _profitAmount < 0
                                ? const Color(0xFFEF4444).withOpacity(0.12)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _profitAmount > 0
                              ? const Color(0xFF10B981).withOpacity(0.3)
                              : _profitAmount < 0
                                  ? const Color(0xFFEF4444).withOpacity(0.3)
                                  : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _profitAmount > 0
                                    ? Icons.trending_up
                                    : _profitAmount < 0
                                        ? Icons.trending_down
                                        : Icons.remove,
                                color: _profitAmount > 0
                                    ? const Color(0xFF10B981)
                                    : _profitAmount < 0
                                        ? const Color(0xFFEF4444)
                                        : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profitAmount < 0
                                        ? '⚠️ بيع بخسارة!'
                                        : 'ربح القطعة الواحدة التقديري:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _profitAmount < 0 ? const Color(0xFFEF4444) : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${_profitAmount >= 0 ? '+' : ''}${CurrencyFormatter.format(_profitAmount)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _profitAmount > 0
                                          ? const Color(0xFF10B981)
                                          : _profitAmount < 0
                                              ? const Color(0xFFEF4444)
                                              : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _profitAmount > 0
                                  ? const Color(0xFF10B981)
                                  : _profitAmount < 0
                                      ? const Color(0xFFEF4444)
                                      : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'نسبة الربح: ${_profitMarginPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // -------------------------------------------------------------
              // بطاقة 3: إدارة المخزون وتنبيهات النقص (Inventory & Stock)
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.warehouse_outlined, color: Colors.blueGrey, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'المخزون والكميات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'الكمية المتوفرة حالياً بالمتجر *',
                        prefixIcon: const Icon(Icons.numbers_outlined, color: AppColors.primaryIndigo),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'أدخل الكمية' : null,
                    ),
                    const SizedBox(height: 10),

                    // أزرار زيادة المخزون السريعة (+10, +25, +50, +100)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text('تزويد سريع: ', style: TextStyle(fontSize: 12, color: Colors.grey, height: 2.2)),
                        ActionChip(
                          label: const Text('+10'),
                          onPressed: () => _addQuickStock(10),
                        ),
                        ActionChip(
                          label: const Text('+25'),
                          onPressed: () => _addQuickStock(25),
                        ),
                        ActionChip(
                          label: const Text('+50'),
                          onPressed: () => _addQuickStock(50),
                        ),
                        ActionChip(
                          label: const Text('+100'),
                          onPressed: () => _addQuickStock(100),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // الشريط السفلي الثابت للزر الكبير والواضح
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: cardBgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saveProduct,
            icon: const Icon(Icons.check_circle_outline, size: 22),
            label: Text(
              isEditing ? 'حفظ التعديلات في المخزون' : 'إضافة السلعة للمخزون (تأكيد)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }
}
