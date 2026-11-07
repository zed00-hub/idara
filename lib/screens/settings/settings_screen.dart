import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/backup_service.dart';
import '../../providers/app_settings_provider.dart';
import 'pin_lock_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (settings.protectSettings && !_isAuthenticated) {
      final allowed = await PinLockDialog.verify(
        context,
        title: 'أدخل PIN للوصول إلى الإعدادات',
        isProtected: true,
      );
      if (!allowed) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _isAuthenticated = true;
    }
  }

  void _editStoreDetails() {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    final nameCtrl = TextEditingController(text: settings.storeName);
    final phoneCtrl = TextEditingController(text: settings.storePhone);
    final addressCtrl = TextEditingController(text: settings.storeAddress);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات المحل للفواتير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المحل *')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            const SizedBox(height: 8),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await settings.updateStoreDetails(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _changePinDialog() {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعيين / تغيير رمز PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اترك الحقل فارغاً لإلغاء القفل برمز PIN', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'رمز PIN الجديد (أرقام)', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newPin = pinCtrl.text.trim();
              await settings.setPin(newPin.isEmpty ? null : newPin);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(newPin.isEmpty ? 'تم إلغاء رمز PIN' : 'تم تفعيل رمز PIN بنجاح')),
                );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Store Info Card
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.storefront, color: Colors.white),
              ),
              title: Text(settings.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${settings.storePhone.isNotEmpty ? settings.storePhone : "بدون هاتف"} • ${settings.storeAddress}'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editStoreDetails,
            ),
          ),
          const SizedBox(height: 12),

          // Security Card
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('الأمان وصلاحيات الوصول', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('رمز الدخول السري (PIN)'),
                  subtitle: Text(settings.isPinEnabled ? 'مفعل ومحمي 🔒' : 'معطل 🔓'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePinDialog,
                ),
                if (settings.isPinEnabled) ...[
                  SwitchListTile(
                    title: const Text('حماية تقارير الأرباح بالـ PIN'),
                    value: settings.protectReports,
                    onChanged: (val) => settings.setProtectionRules(
                      reports: val,
                      settings: settings.protectSettings,
                      prices: settings.protectPrices,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('حماية الإعدادات بالـ PIN'),
                    value: settings.protectSettings,
                    onChanged: (val) => settings.setProtectionRules(
                      reports: settings.protectReports,
                      settings: val,
                      prices: settings.protectPrices,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('حماية تعديل الأسعار بالـ PIN'),
                    value: settings.protectPrices,
                    onChanged: (val) => settings.setProtectionRules(
                      reports: settings.protectReports,
                      settings: settings.protectSettings,
                      prices: val,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Backup & Restore Card
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('النسخ الاحتياطي واستعادة البيانات', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                  title: const Text('تصدير نسخة احتياطية شاملة'),
                  subtitle: const Text('حفظ نسخة مشفرة من كافة المبيعات والديون والسلع'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final path = await BackupService.exportFullBackup();
                    if (path != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تصدير النسخة الاحتياطية بنجاح ✓')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined, color: AppColors.accentDark),
                  title: const Text('استعادة البيانات من نسخة احتياطية'),
                  subtitle: const Text('استرجاع البيانات من ملف Backup سابق'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final ok = await BackupService.restoreFromBackup();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'تمت استعادة البيانات بنجاح ✓' : 'فشلت الاستعادة أو تم إلغاؤها'),
                          backgroundColor: ok ? AppColors.success : AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Display & Language Card
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('المظهر واللغة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                SwitchListTile(
                  secondary: Icon(settings.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('الوضع الليلي (Dark Mode)'),
                  value: settings.isDarkMode,
                  onChanged: (val) => settings.toggleTheme(val),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('لغة التطبيق'),
                  subtitle: Text(settings.language == 'ar' ? 'العربية 🇩🇿' : 'Français 🇫🇷'),
                  trailing: DropdownButton<String>(
                    value: settings.language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                    ],
                    onChanged: (l) {
                      if (l != null) settings.setLanguage(l);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // About app
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, color: AppColors.accent, size: 20),
                      SizedBox(width: 8),
                      Text('نظمها (Nadmha POS) - الإصدار 1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text('نظام نقاط بيع أوفلاين 100% مدمج مع 42,000 منتج جزائري', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
