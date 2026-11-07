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
        const SnackBar(
          content: Text('✅ تم تحديث بيانات السلعة بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onAddProduct() async {
    final updated = await ProductFormDialog.show(context);
    if (updated != null && mounted) {
      await Provider.of<InventoryProvider>(context, listen: false).addOrUpdateProduct(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تمت إضافة السلعة بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text(
                        'قائمة النواقص (${lowStock.length} سلعة)',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final shortagesData = lowStock.map((p) => {
                        'name': p.name,
                        'requested_qty': 10,
                      }).toList();
                      PrintService.shareShortagesList(shortages: shortagesData);
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('واتساب للمورد', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: lowStock.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 48, color: AppColors.accent),
                            const SizedBox(height: 10),
                            const Text('المخزون ممتاز! لا توجد سلع نافدة حالياً', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: lowStock.length,
                        itemBuilder: (ctx, i) {
                          final item = lowStock[i];
                          return Card(
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                              ),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('باركود: ${item.barcode} • المتبقي: ${item.quantity.toInt()}'),
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
  }

  @override
  Widget build(BuildContext context) {
    final inv = Provider.of<InventoryProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2, color: AppColors.primaryIndigo, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المخزون والكتالوج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('42,010 منتج جزائري مدمج', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_outlined, color: AppColors.danger),
            tooltip: 'قائمة النواقص',
            onPressed: _showShortagesModal,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primaryIndigo),
            tooltip: 'تصدير كملف Excel/CSV',
            onPressed: () async {
              final path = await BackupService.exportProductsCsv();
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تصدير ملف جرد السلع بنجاح'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddProduct,
        backgroundColor: AppColors.primaryIndigo,
        foregroundColor: Colors.white,
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
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryIndigo),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
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
            height: 42,
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
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryIndigo,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                            Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لا توجد سلع مطابقة للبحث', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: inv.products.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemBuilder: (context, i) {
                          final p = inv.products[i];
                          return Card(
                            child: ListTile(
                              onTap: () => _onEditProduct(p),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryIndigo.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    p.category.isNotEmpty ? p.category[0] : 'س',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryIndigo),
                                  ),
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.retailColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'تجزئة: ${CurrencyFormatter.format(p.retailPrice)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.retailColor),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('جملة: ${p.wholesalePrice.round()} دج', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (p.quantity <= 5 ? AppColors.danger : AppColors.success).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'الكمية: ${p.quantity.toInt()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: p.quantity <= 5 ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
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
