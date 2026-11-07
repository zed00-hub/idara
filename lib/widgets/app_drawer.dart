import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/services/backup_service.dart';
import '../providers/app_settings_provider.dart';
import '../screens/reports/financial_reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = Provider.of<AppSettingsProvider>(context);

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  settings.storeName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.storePhone.isNotEmpty ? settings.storePhone : 'نظام نقاط بيع أوفلاين 100%',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                ),
              ],
            ),
          ),

          // Drawer Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.analytics_outlined,
                  color: AppColors.primaryIndigo,
                  title: 'التقارير المالية و Z-Report',
                  subtitle: 'أرباح اليوم، حركة الصندوق، والمصاريف',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FinancialReportsScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.wholesaleColor,
                  title: 'الموردين وتصوير فواتير الشراء 📷',
                  subtitle: 'حسابات الموردين وتصوير الوصل بالكاميرا',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  color: AppColors.retailColor,
                  title: 'إعدادات المحل والطباعة الحرارية',
                  subtitle: 'ربط الطابعة الحرارية ESC/POS وترويسة الفاتورة',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.cloud_download_outlined,
                  color: AppColors.accentDark,
                  title: 'النسخ الاحتياطي السريع (تصدير)',
                  subtitle: 'حفظ نسخة أمان لبياناتك ومشاركتها في ثوانٍ',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final path = await BackupService.exportFullBackup();
                    if (path != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ تم إنشاء النسخة الاحتياطية بنجاح'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 20),
                _buildDrawerItem(
                  context: context,
                  icon: settings.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: Colors.amber,
                  title: settings.isDarkMode ? 'تفعيل الوضع النهاري' : 'تفعيل الوضع الليلي',
                  subtitle: 'تغيير مظهر وألوان التطبيق',
                  onTap: () {
                    settings.toggleTheme(!settings.isDarkMode);
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'نظمها POS v1.2.0 • كتالوج 42,010 منتج مدمج أوفلاين',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
