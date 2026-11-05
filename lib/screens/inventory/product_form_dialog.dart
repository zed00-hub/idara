import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  static Future<Product?> show(BuildContext context, {Product? product}) {
    return showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductFormDialog(product: product),
    );
  }

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _retailCtrl;
  late TextEditingController _wholesaleCtrl;
  late TextEditingController _qtyCtrl;
  String _selectedCategory = 'عام';
  String _selectedUnit = 'piece';

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _costCtrl = TextEditingController(text: (p?.costPrice ?? 0).round().toString());
    _retailCtrl = TextEditingController(text: (p?.retailPrice ?? 0).round().toString());
    _wholesaleCtrl = TextEditingController(text: (p?.wholesalePrice ?? 0).round().toString());
    _qtyCtrl = TextEditingController(text: (p?.quantity ?? 0).toInt().toString());
    _selectedCategory = p?.category ?? 'عام';
    _selectedUnit = p?.unit ?? 'piece';
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _retailCtrl.dispose();
    _wholesaleCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    final scannedCode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('امسح الباركود'),
        content: SizedBox(
          width: 280,
          height: 240,
          child: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                Navigator.of(ctx).pop(barcodes.first.rawValue!);
              }
            },
          ),
        ),
      ),
    );

    if (scannedCode != null) {
      setState(() => _barcodeCtrl.text = scannedCode);
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final updatedProduct = Product(
        id: widget.product?.id,
        barcode: _barcodeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        costPrice: double.tryParse(_costCtrl.text.trim()) ?? 0.0,
        retailPrice: double.tryParse(_retailCtrl.text.trim()) ?? 0.0,
        wholesalePrice: double.tryParse(_wholesaleCtrl.text.trim()) ?? 0.0,
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 0.0,
        unit: _selectedUnit,
        category: _selectedCategory,
        isCustom: true,
      );

      Navigator.of(context).pop(updatedProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'تعديل السلعة' : 'إضافة سلعة جديدة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),

                // Barcode + Scanner Icon
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الباركود *',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'أدخل الباركود' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.camera_alt),
                      tooltip: 'مسح الباركود',
                      onPressed: _scanBarcode,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم السلعة / المنتج *',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'أدخل اسم السلعة' : null,
                ),
                const SizedBox(height: 12),

                // Prices: Retail + Wholesale + Cost
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _retailCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر التجزئة (دج) *',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'أدخل السعر' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _wholesaleCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر الجملة (دج)',
                          prefixIcon: Icon(Icons.inventory_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر الشراء / التكلفة (دج)',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المخزون الحالي',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category & Unit
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'الفئة'),
                        items: InventoryProvider.defaultCategories
                            .where((c) => c != 'الكل')
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? 'عام'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(labelText: 'الوحدة'),
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
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    isEditing ? 'حفظ التعديلات' : 'إضافة السلعة',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
