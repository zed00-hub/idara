import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/app_drawer.dart';
import '../settings/pin_lock_dialog.dart';
import 'product_form_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isGridView = false;

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

  void _onDeleteProduct(Product p) async {
    if (p.id == null) return;
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (settings.protectPrices) {
      final allowed = await PinLockDialog.verify(
        context,
        title: 'أدخل PIN لحذف السلعة من المخزون',
        isProtected: true,
      );
      if (!allowed) return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السلعة'),
        content: Text('هل أنت متأكد من حذف سلعة "${p.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<InventoryProvider>(context, listen: false).deleteProduct(p.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حذف السلعة بنجاح'),
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

  Future<void> _showValuationModal() async {
    final inv = Provider.of<InventoryProvider>(context, listen: false);
    final val = await inv.getInventoryValuation();
    final totalCost = val['totalCost'] ?? 0.0;
    final totalRetail = val['totalRetail'] ?? 0.0;
    final projectedProfit = val['potentialProfit'] ?? 0.0;
    final margin = val['potentialMargin'] ?? 0.0;
    final totalUnits = (val['totalStock'] ?? 0.0).toInt();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryIndigo.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet, color: AppColors.primaryIndigo),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'تقييم رأس مال المخزون والأرباح',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildValuationStat(
                      title: 'رأس المال المستثمر',
                      subtitle: 'تكلفة الشراء الكلية',
                      value: CurrencyFormatter.format(totalCost),
                      color: AppColors.primaryIndigo,
                      icon: Icons.monetization_on_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValuationStat(
                      title: 'القيمة البيعية الكلية',
                      subtitle: 'سعر البيع الإجمالي',
                      value: CurrencyFormatter.format(totalRetail),
                      color: AppColors.accent,
                      icon: Icons.storefront_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildValuationStat(
                      title: 'الربح الإجمالي المتوقع',
                      subtitle: 'نسبة الهامش: ${margin.toStringAsFixed(1)}%',
                      value: CurrencyFormatter.format(projectedProfit),
                      color: projectedProfit >= 0 ? const Color(0xFF10B981) : AppColors.danger,
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValuationStat(
                      title: 'حجم المخزون الفعلي',
                      subtitle: 'إجمالي القطع المتوفرة',
                      value: '$totalUnits قطعة',
                      color: const Color(0xFFF59E0B),
                      icon: Icons.inventory,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValuationStat({
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = Provider.of<InventoryProvider>(context);
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
            icon: const Icon(Icons.analytics_outlined, color: AppColors.primaryIndigo),
            tooltip: 'تقييم رأس مال المخزون والأرباح',
            onPressed: _showValuationModal,
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_outlined, color: AppColors.danger),
            tooltip: 'قائمة النواقص',
            onPressed: _showShortagesModal,
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

          // View Toggle & Total Counter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${inv.products.length} سلعة معروضة',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isGridView = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: !_isGridView ? AppColors.primaryIndigo : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.view_list_rounded,
                            size: 18,
                            color: !_isGridView ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isGridView = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isGridView ? AppColors.primaryIndigo : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 18,
                            color: _isGridView ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Products List / Grid
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
                    : _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.95,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: inv.products.length,
                            itemBuilder: (context, i) {
                              final p = inv.products[i];
                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.8),
                                ),
                                child: InkWell(
                                  onTap: () => _onEditProduct(p),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryIndigo.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                p.category.isNotEmpty ? p.category : 'عام',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryIndigo),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (p.quantity <= 5 ? AppColors.danger : AppColors.success).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${p.quantity.toInt()} في المخزن',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: p.quantity <= 5 ? AppColors.danger : AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          p.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.barcode,
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        const Divider(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              CurrencyFormatter.format(p.retailPrice),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryIndigo,
                                              ),
                                            ),
                                            const Icon(Icons.edit_note, size: 18, color: Colors.grey),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _onEditProduct(p);
                                  } else if (action == 'delete') {
                                    _onDeleteProduct(p);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18, color: AppColors.primaryIndigo),
                                        SizedBox(width: 8),
                                        Text('تعديل السلعة'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        SizedBox(width: 8),
                                        Text('حذف السلعة', style: TextStyle(color: AppColors.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
