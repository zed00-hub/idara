import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/app_drawer.dart';
import 'barcode_scanner_screen.dart';
import 'checkout_dialog.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  void _openBarcodeScanner() async {
    final pos = Provider.of<POSProvider>(context, listen: false);
    await BarcodeScannerScreen.open(context, isMultiScan: pos.isMultiScan);
  }

  void _showManualSearchDialog() {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final pos = Provider.of<POSProvider>(context, listen: false);
    final searchCtrl = TextEditingController();

    invProv.searchProducts('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final products = Provider.of<InventoryProvider>(ctx).products;
            final isLoading = Provider.of<InventoryProvider>(ctx).isLoading;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'ابحث في 42,000 منتج بالاسم أو الباركود...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.primaryIndigo),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text('لا توجد منتجات مطابقة للبحث'),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: products.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final p = products[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryIndigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryIndigo, size: 22),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'باركود: ${p.barcode} • تجزئة: ${p.retailPrice.round()} دج • جملة: ${p.wholesalePrice.round()} دج',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      pos.addToCart(p);
                                      AudioService.playScanBeep();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ تمت إضافة: ${p.name}'),
                                          duration: const Duration(milliseconds: 900),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryIndigo,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('إضافة +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryIndigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart, color: AppColors.primaryIndigo, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سلعة متفرقة / بدون باركود', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('إضافة سريعة لسلعة مباشرة للسلة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'اسم السلعة (خبز، خضر، ميزان...)',
                  hintText: 'مثال: خبز تقليدي أو خضر',
                  prefixIcon: const Icon(Icons.label_outline, color: AppColors.primaryIndigo),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'السعر الإفرادي (دج) *',
                        hintText: 'مثال: 50',
                        prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.retailColor),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'الكمية',
                        prefixIcon: const Icon(Icons.numbers_outlined),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // أسعار سريعة شائعة
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('سعر سريع: ', style: TextStyle(fontSize: 12, color: Colors.grey, height: 2.2)),
                  ActionChip(
                    label: const Text('10 دج'),
                    onPressed: () => priceCtrl.text = '10',
                  ),
                  ActionChip(
                    label: const Text('20 دج'),
                    onPressed: () => priceCtrl.text = '20',
                  ),
                  ActionChip(
                    label: const Text('50 دج'),
                    onPressed: () => priceCtrl.text = '50',
                  ),
                  ActionChip(
                    label: const Text('100 دج'),
                    onPressed: () => priceCtrl.text = '100',
                  ),
                  ActionChip(
                    label: const Text('200 دج'),
                    onPressed: () => priceCtrl.text = '200',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim().isEmpty ? 'سلعة متفرقة' : nameCtrl.text.trim();
                        final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                        final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;

                        if (price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ يرجى إدخال سعر صحيح أكبر من 0 دج'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        final customProduct = Product(
                          barcode: 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          retailPrice: price,
                          wholesalePrice: price,
                          isCustom: true,
                        );

                        pos.addToCart(customProduct, qty: qty);
                        AudioService.playScanBeep();
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('إضافة للسلة ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addQuickPreset(String name, double price) {
    final pos = Provider.of<POSProvider>(context, listen: false);
    final p = Product(
      barcode: 'QUICK-${name.hashCode.abs()}',
      name: name,
      retailPrice: price,
      wholesalePrice: price,
      isCustom: true,
    );
    pos.addToCart(p);
    AudioService.playScanBeep();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ أضيف: $name ($price دج)'),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 26),
            tooltip: 'القائمة الرئيسية',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale, color: AppColors.primaryIndigo, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نظمها POS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('الكاشير ونقاط البيع', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryIndigo),
            tooltip: 'مسح باركود بالكاميرا',
            onPressed: _openBarcodeScanner,
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primaryIndigo),
            tooltip: 'بحث في 42,000 منتج',
            onPressed: _showManualSearchDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Action Card: Scan Barcode Button + Mode Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryIndigo.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Prominent Scanner Button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _openBarcodeScanner,
                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                      label: const Text(
                        'مسح باركود بالكاميرا 📷',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryIndigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search 42k button
                  IconButton(
                    onPressed: _showManualSearchDialog,
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.search, color: Colors.white, size: 22),
                    ),
                    tooltip: 'بحث في 42,000 منتج',
                  ),

                  // Clear Cart button
                  if (pos.cart.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('تفريغ السلة؟'),
                            content: const Text('هل أنت متأكد من مسح جميع المنتجات من السلة؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                onPressed: () {
                                  pos.clearCart();
                                  Navigator.of(ctx).pop();
                                },
                                child: const Text('تفريغ'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 22),
                      ),
                      tooltip: 'تفريغ السلة',
                    ),
                ],
              ),
            ),
          ),

          // Quick Action Ribbon: Price Type & Common Quick Items
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // Wholesale / Retail Segmented Toggle
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => pos.setGlobalPriceType(PriceType.retail),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pos.globalPriceType == PriceType.retail ? AppColors.primaryIndigo : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'تجزئة 🛍️',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pos.globalPriceType == PriceType.retail ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => pos.setGlobalPriceType(PriceType.wholesale),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pos.globalPriceType == PriceType.wholesale ? AppColors.wholesaleColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'جملة 🏷️',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pos.globalPriceType == PriceType.wholesale ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Quick Fast Add Chips (خبز، حليب، بيض، ماء...)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickAddChip('🥖 خبز', 15.0),
                        _buildQuickAddChip('🥛 حليب', 25.0),
                        _buildQuickAddChip('🥚 بيض', 25.0),
                        _buildQuickAddChip('💧 ماء 1.5ل', 40.0),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14, color: AppColors.primaryIndigo),
                          label: const Text('أخرى', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _showAddCustomItemDialog,
                          backgroundColor: AppColors.primaryIndigo.withOpacity(0.08),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Cart List
          Expanded(
            child: pos.cart.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: AppColors.primaryIndigo.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_scanner, size: 44, color: AppColors.primaryIndigo),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'سلة المشتريات فارغة',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'اضغط زر الباركود في الوسط أو الزر أعلاه للمسح الفوري',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _openBarcodeScanner,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('تشغيل الماسح بالكاميرا'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryIndigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    itemCount: pos.cart.length,
                    itemBuilder: (context, index) {
                      final item = pos.cart[index];
                      return Dismissible(
                        key: ValueKey('${item.product.barcode}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Row(
                            children: [
                              SizedBox(width: 16),
                              Icon(Icons.delete_outline, color: Colors.white, size: 26),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          pos.removeFromCart(index);
                          AudioService.playScanBeep();
                        },
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Item Number / Icon
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: (item.priceType == PriceType.wholesale ? AppColors.wholesaleColor : AppColors.primaryIndigo).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: item.priceType == PriceType.wholesale ? AppColors.wholesaleColor : AppColors.primaryIndigo,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Item Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => pos.toggleItemPriceType(index),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: item.priceType == PriceType.wholesale
                                                    ? AppColors.wholesaleColor.withOpacity(0.12)
                                                    : AppColors.retailColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.priceType == PriceType.wholesale ? 'جملة 🏷️' : 'تجزئة 🛍️',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.priceType == PriceType.wholesale ? AppColors.wholesaleColor : AppColors.retailColor,
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
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          pos.updateQuantity(index, item.quantity - 1);
                                          AudioService.playScanBeep();
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.remove, size: 18, color: AppColors.danger),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${item.quantity.toInt()}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          pos.updateQuantity(index, item.quantity + 1);
                                          AudioService.playScanBeep();
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.add, size: 18, color: AppColors.accentDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Subtotal
                                SizedBox(
                                  width: 75,
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
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'العدد: ${pos.totalItemsCount} سلع (${pos.cart.length} صنف)',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (pos.discount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'تخفيض: -${pos.discount.round()} دج',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Checkout Action Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: pos.cart.isEmpty ? null : AppColors.accentGradient,
                            color: pos.cart.isEmpty ? Colors.grey.shade400 : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: pos.cart.isEmpty
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: pos.cart.isEmpty ? null : () => CheckoutDialog.show(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.payment, size: 20),
                                    SizedBox(width: 8),
                                    Text('إتمام البيع (الدفع)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    CurrencyFormatter.format(pos.netTotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddChip(String label, double price) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: () => _addQuickPreset(label.replaceAll(RegExp(r'[^\u0621-\u064A\s]'), '').trim(), price),
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
