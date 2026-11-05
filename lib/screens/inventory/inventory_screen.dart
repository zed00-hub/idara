import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/inventory_provider.dart';
import '../settings/pin_lock_dialog.dart';
import 'product_form_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).searchProducts('');
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onEditProduct(Product p) async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (settings.protectPrices) {
      final allowed = await PinLockDialog.verify(
        context,
        title: 'أدخل PIN لتعديل أسعار وبيانات السلعة',
        isProtected: true,
      );
      if (!allowed) return;
    }

    if (!mounted) return;
    final updated = await ProductFormDialog.show(context, product: p);
    if (updated != null && mounted) {
      await Provider.of<InventoryProvider>(context, listen: false).addOrUpdateProduct(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث بيانات السلعة بنجاح')),
      );
    }
  }

  void _onAddProduct() async {
    final updated = await ProductFormDialog.show(context);
    if (updated != null && mounted) {
      await Provider.of<InventoryProvider>(context, listen: false).addOrUpdateProduct(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة السلعة بنجاح')),
      );
    }
  }

  void _showShortagesModal() async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final lowStock = await invProv.getLowStockProducts(threshold: 5.0);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'قائمة النواقص (${lowStock.length} سلعة)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final shortagesData = lowStock.map((p) => {
                        'name': p.name,
                        'requested_qty': 10,
                      }).toList();
                      PrintService.shareShortagesList(shortages: shortagesData);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('واتساب للمورد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: lowStock.isEmpty
                    ? const Center(child: Text('المخزون ممتاز! لا توجد سلع نافدة حالياً'))
                    : ListView.builder(
                        itemCount: lowStock.length,
                        itemBuilder: (ctx, i) {
                          final item = lowStock[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.danger.withOpacity(0.12),
                              child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('باركود: ${item.barcode} • المتبقي: ${item.quantity.toInt()}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = Provider.of<InventoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون والسلع (42 ألف منتج)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.production_quantity_limits),
            tooltip: 'قائمة النواقص',
            onPressed: _showShortagesModal,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'تصدير كملف Excel/CSV',
            onPressed: () async {
              final path = await BackupService.exportProductsCsv();
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير ملف جرد السلع بنجاح')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddProduct,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text('إضافة سلعة', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث في 42,000 منتج بالاسم أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          inv.searchProducts('');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => inv.searchProducts(val),
            ),
          ),

          // Categories Chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: InventoryProvider.defaultCategories.length,
              itemBuilder: (context, i) {
                final cat = InventoryProvider.defaultCategories[i];
                final isSelected = inv.selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.18),
                    onSelected: (_) => inv.setCategory(cat),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Products List
          Expanded(
            child: inv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : inv.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لا توجد سلع مطابقة للبحث', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: inv.products.length,
                        itemBuilder: (context, i) {
                          final p = inv.products[i];
                          return Card(
                            child: ListTile(
                              onTap: () => _onEditProduct(p),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  p.category.isNotEmpty ? p.category[0] : 'س',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Text('تجزئة: ${CurrencyFormatter.format(p.retailPrice)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  const SizedBox(width: 8),
                                  Text('جملة: ${p.wholesalePrice.round()} دج', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const Spacer(),
                                  Text(
                                    'المخزون: ${p.quantity.toInt()}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: p.quantity <= 5 ? AppColors.danger : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.edit_outlined, size: 20),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
