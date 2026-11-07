import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/product.dart';
import '../providers/pos_provider.dart';
import '../widgets/app_drawer.dart';
import 'debts/customer_debts_screen.dart';
import 'inventory/inventory_screen.dart';
import 'invoices/invoice_history_screen.dart';
import 'pos/barcode_scanner_screen.dart';
import 'pos/pos_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  final List<Widget> _screens = const [
    POSScreen(),
    InventoryScreen(),
    InvoiceHistoryScreen(),
    CustomerDebtsScreen(),
  ];

  final List<String> _titles = const [
    'الكاشير ونقاط البيع',
    'المخزون والكتالوج',
    'سجل الفواتير والمبيعات',
    'ديون الزبائن (الكريدي)',
  ];

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('اضغط رجوع مرة أخرى للخروج من التطبيق'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return false;
    }

    return true;
  }

  void _openBarcodeScanner() async {
    final pos = Provider.of<POSProvider>(context, listen: false);
    await BarcodeScannerScreen.open(context, isMultiScan: pos.isMultiScan);
  }

  void _showCenterActionMenu() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pos = Provider.of<POSProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'العمليات والمسح السريع',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),

            // Option 1: Fullscreen Camera Scanner
            _buildActionItem(
              icon: Icons.qr_code_scanner,
              color: AppColors.primaryIndigo,
              title: 'مسح باركود بالكاميرا (سكانر فوري)',
              subtitle: 'فتح الكاميرا بحجم كامل وقراءة سريعة مع الليزر',
              onTap: () {
                Navigator.of(ctx).pop();
                _openBarcodeScanner();
              },
            ),

            const SizedBox(height: 10),
            // Option 2: Price Checker
            _buildActionItem(
              icon: Icons.price_check,
              color: AppColors.accent,
              title: 'فحص سعر سلعة (جرد سريع)',
              subtitle: 'معرفة سعر التجزئة والجملة والمخزون المتبقي',
              onTap: () async {
                Navigator.of(ctx).pop();
                final product = await BarcodeScannerScreen.open(context, isMultiScan: false);
                if (product != null && mounted) {
                  _showPriceInfoDialog(product);
                }
              },
            ),

            const SizedBox(height: 10),
            // Option 3: Add unbarcoded custom product
            _buildActionItem(
              icon: Icons.add_shopping_cart,
              color: AppColors.creditColor,
              title: 'سلعة بدون باركود (ميزان/خبز/خضر)',
              subtitle: 'إضافة سلعة بسعر حر إلى سلة الكاشير',
              onTap: () {
                Navigator.of(ctx).pop();
                _showAddCustomItemDialog();
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _showPriceInfoDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primaryIndigo),
            const SizedBox(width: 8),
            Expanded(child: Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الباركود: ${product.barcode}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.retailColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سعر التجزئة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${product.retailPrice.round()} دج',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.retailColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.wholesaleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سعر الجملة:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${product.wholesalePrice.round()} دج',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.wholesaleColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('الكمية في المخزون: ${product.quantity.toInt()} قطعة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
        ],
      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart, color: AppColors.primaryIndigo),
            SizedBox(width: 8),
            Text('سلعة متفرقة / بدون باركود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم السلعة (خبز، خضر، ميزان...)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر الإفرادي (دج) *', prefixIcon: Icon(Icons.payments)),
            ),
            const SizedBox(height: 10),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        // Modern Navigation Drawer (القائمة الجانبية بالضغط على ☰)
        drawer: const AppDrawer(),

        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),

        // Floating Center Action Button (بارز واظهر وأعلى شوي)
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryIndigo.withOpacity(0.45),
                blurRadius: 14,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _showCenterActionMenu,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            tooltip: 'مسح الباركود والعمليات',
            child: const Icon(Icons.qr_code_scanner, size: 30),
          ),
        ),

        // Bottom Navigation Bar with 4 Sections
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          elevation: 10,
          color: isDark ? AppColors.darkSurface : Colors.white,
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Tabs: POS & Inventory
              Row(
                children: [
                  _buildNavTab(index: 0, icon: Icons.point_of_sale_outlined, activeIcon: Icons.point_of_sale, label: 'الكاشير'),
                  const SizedBox(width: 10),
                  _buildNavTab(index: 1, icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'المخزون'),
                ],
              ),

              // Spacer for center elevated button
              const SizedBox(width: 48),

              // Right Tabs: Invoices & Debts
              Row(
                children: [
                  _buildNavTab(index: 2, icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'الفواتير'),
                  const SizedBox(width: 10),
                  _buildNavTab(index: 3, icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt, label: 'الكريدي'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primaryIndigo : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primaryIndigo : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
