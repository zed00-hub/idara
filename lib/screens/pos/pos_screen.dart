import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';
import 'checkout_dialog.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isTorchOn = false;
  bool _isScannerVisible = true;
  final TextEditingController _manualBarcodeController = TextEditingController();

  @override
  void dispose() {
    _scannerController.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    final pos = Provider.of<POSProvider>(context, listen: false);

    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        pos.handleBarcodeScanned(barcode.rawValue!);
        if (!pos.isMultiScan) {
          break; // Single scan takes first recognized code
        }
      }
    }
  }

  void _showManualSearchDialog() {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final pos = Provider.of<POSProvider>(context, listen: false);
    final searchCtrl = TextEditingController();

    invProv.searchProducts('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final products = Provider.of<InventoryProvider>(ctx).products;
            final isLoading = Provider.of<InventoryProvider>(ctx).isLoading;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'ابحث في 42,000 منتج بالاسم أو الباركود...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      invProv.searchProducts('');
                                      setSheetState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            invProv.searchProducts(val);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const LinearProgressIndicator()
                  else
                    Expanded(
                      child: products.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة'))
                          : ListView.builder(
                              itemCount: products.length,
                              itemBuilder: (ctx, i) {
                                final p = products[i];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                                  ),
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('باركود: ${p.barcode} • تجزئة: ${p.retailPrice.round()} دج • جملة: ${p.wholesalePrice.round()} دج'),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      pos.addToCart(p);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تمت إضافة ${p.name} للسلة'),
                                          duration: const Duration(milliseconds: 700),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    child: const Text('إضافة +'),
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final pos = Provider.of<POSProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة سلعة بدون باركود (ميزان/متفرقات)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم السلعة (مثلاً: خبز، خضر...)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر الإفرادي (دج) *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية / الوزن'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim().isEmpty ? 'سلعة متفرقة' : nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;

              final customProduct = Product(
                barcode: 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                retailPrice: price,
                wholesalePrice: price,
                isCustom: true,
              );

              pos.addToCart(customProduct, qty: qty);
              Navigator.of(ctx).pop();
            },
            child: const Text('إضافة للسلة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الكاشير ونقاط البيع (POS)'),
        actions: [
          // Toggle Camera View Button
          IconButton(
            icon: Icon(_isScannerVisible ? Icons.camera_alt : Icons.camera_alt_outlined),
            tooltip: 'إظهار/إخفاء الكاميرا',
            onPressed: () => setState(() => _isScannerVisible = !_isScannerVisible),
          ),
          // Flashlight Toggle
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'فلاش الكاميرا',
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          // Manual Search
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث يدوي في الكتالوج',
            onPressed: _showManualSearchDialog,
          ),
          // Add custom unbarcoded product
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'سلعة بدون باركود',
            onPressed: _showAddCustomItemDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 35% Upper Portion: Smart Camera Barcode Scanner
          if (_isScannerVisible)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.32,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                  ),
                  // Scanner Overlay Viewfinder
                  Center(
                    child: Container(
                      width: 260,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: pos.isMultiScan ? AppColors.accent : Colors.white,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Single / Multi-Scan Switch Floating Pill
                  Positioned(
                    top: 10,
                    right: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                pos.isMultiScan ? Icons.document_scanner : Icons.qr_code_scanner,
                                color: pos.isMultiScan ? AppColors.accent : Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pos.isMultiScan ? 'وضع المسح المتعدد ⚡' : 'وضع المسح الأحادي 🎯',
                                style: TextStyle(
                                  color: pos.isMultiScan ? AppColors.accent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: pos.isMultiScan,
                            activeColor: AppColors.accent,
                            onChanged: (val) => pos.toggleMultiScan(val),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 65% Lower Portion: Cart List and Live Totals
          Expanded(
            child: pos.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'السلة فارغة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        const Text('امسح الباركود بالكاميرا أو ابحث عن السلعة أعلاه', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: pos.cart.length,
                    itemBuilder: (context, index) {
                      final item = pos.cart[index];
                      return Dismissible(
                        key: ValueKey('${item.product.barcode}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.danger,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => pos.removeFromCart(index),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                // Item Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => pos.toggleItemPriceType(index),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: item.priceType == PriceType.wholesale
                                                    ? AppColors.primary.withOpacity(0.12)
                                                    : AppColors.accent.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.priceType == PriceType.wholesale ? 'جملة 🏷️' : 'تجزئة 🛍️',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.priceType == PriceType.wholesale ? AppColors.primary : AppColors.accentDark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${item.unitPrice.round()} دج',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Quantity Controls (- / +)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 22),
                                      onPressed: () => pos.updateQuantity(index, item.quantity - 1),
                                    ),
                                    Text(
                                      '${item.quantity.toInt()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: AppColors.success, size: 22),
                                      onPressed: () => pos.updateQuantity(index, item.quantity + 1),
                                    ),
                                  ],
                                ),

                                // Subtotal
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom POS Summary & Checkout Action Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Items count & Clear Cart
                      Row(
                        children: [
                          Text(
                            'السلع: ${pos.totalItemsCount}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (pos.cart.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () => pos.clearCart(),
                              child: const Text('إفراغ 🗑️', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                      // Total Amount
                      Row(
                        children: [
                          const Text('الإجمالي: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(
                            CurrencyFormatter.format(pos.netTotal),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Checkout Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: pos.cart.isEmpty ? null : () => CheckoutDialog.show(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black87,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            pos.cart.isEmpty ? 'السلة فارغة' : 'إتمام البيع (${CurrencyFormatter.format(pos.netTotal)})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
