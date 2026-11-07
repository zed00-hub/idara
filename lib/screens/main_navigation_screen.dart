import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import 'debts/customer_debts_screen.dart';
import 'hub/management_hub_screen.dart';
import 'inventory/inventory_screen.dart';
import 'invoices/invoice_history_screen.dart';
import 'pos/pos_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  final List<Widget> _screens = const [
    POSScreen(),
    InventoryScreen(),
    InvoiceHistoryScreen(),
    CustomerDebtsScreen(),
    ManagementHubScreen(),
  ];

  Future<bool> _onWillPop() async {
    // 1. If not on POS screen, switch back to POS screen first
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    // 2. If already on POS, require double tap within 2 seconds to exit
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

    return true; // Exits app safely
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
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            height: 68,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.primaryIndigo.withOpacity(0.12),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primaryIndigo),
                label: 'الكاشير',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2, color: AppColors.primaryIndigo),
                label: 'المخزون',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: AppColors.primaryIndigo),
                label: 'الفواتير',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt, color: AppColors.primaryIndigo),
                label: 'الكريدي',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view, color: AppColors.primaryIndigo),
                label: 'المزيد',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
