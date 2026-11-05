import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/financial_report_provider.dart';
import '../settings/pin_lock_dialog.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  ZReportSummary? _zReport;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoad();
    });
  }

  void _checkAuthAndLoad() async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (settings.protectReports && !_isAuthenticated) {
      final allowed = await PinLockDialog.verify(
        context,
        title: 'أدخل PIN لعرض التقارير والأرباح',
        isProtected: true,
      );
      if (!allowed) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _isAuthenticated = true;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final reportProv = Provider.of<FinancialReportProvider>(context, listen: false);
    await reportProv.loadCurrentRegister();
    await reportProv.loadExpenses();
    final z = await reportProv.generateDailyZReport();

    if (mounted) {
      setState(() {
        _zReport = z;
        _isLoading = false;
      });
    }
  }

  void _showOpenRegisterDialog() {
    final amountCtrl = TextEditingController(text: '5000');
    final notesCtrl = TextEditingController();
    final reportProv = Provider.of<FinancialReportProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فتح صندوق اليوم (رصيد البداية)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مبلغ الفكة الافتتاحي (دج) *', prefixIcon: Icon(Icons.point_of_sale)),
            ),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              await reportProv.openCashRegister(amount, notes: notesCtrl.text.trim());
              Navigator.of(ctx).pop();
              _loadData();
            },
            child: const Text('تأكيد الفتح'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'كهرباء وإنارة';
    final reportProv = Provider.of<FinancialReportProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('تسجيل مصروف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'بيان المصروف (السبب) *')),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (دج) *')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'نوع المصروف'),
                items: const [
                  DropdownMenuItem(value: 'كهرباء وإنارة', child: Text('كهرباء وإنارة')),
                  DropdownMenuItem(value: 'إيجار المحل', child: Text('إيجار المحل')),
                  DropdownMenuItem(value: 'يوميات عمال', child: Text('يوميات عمال')),
                  DropdownMenuItem(value: 'نقل وشحن', child: Text('نقل وشحن')),
                  DropdownMenuItem(value: 'أخرى', child: Text('مصاريف أخرى')),
                ],
                onChanged: (val) => setDlgState(() => category = val ?? 'أخرى'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (titleCtrl.text.trim().isNotEmpty && amount > 0) {
                  await reportProv.addExpense(title: titleCtrl.text.trim(), amount: amount, category: category);
                  Navigator.of(ctx).pop();
                  _loadData();
                }
              },
              child: const Text('تسجيل المصروف'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportProv = Provider.of<FinancialReportProvider>(context);
    final register = reportProv.activeRegister;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والأرباح (Z-Report)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cash Register Status Card
                  Card(
                    color: register != null ? AppColors.primary.withOpacity(0.08) : Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            register != null ? Icons.lock_open : Icons.lock_outline,
                            size: 36,
                            color: register != null ? AppColors.primary : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  register != null ? 'الصندوق مفتوح حالياً' : 'الصندوق مغلق',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  register != null
                                      ? 'رصيد الافتتاح: ${CurrencyFormatter.format(register.openingAmount)}'
                                      : 'قم بفتح الصندوق لبدء دورة العمل اليومية',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          if (register == null)
                            ElevatedButton(
                              onPressed: _showOpenRegisterDialog,
                              child: const Text('فتح الصندوق'),
                            )
                          else
                            OutlinedButton(
                              onPressed: () async {
                                final countCtrl = TextEditingController(text: (_zReport?.expectedDrawerCash ?? 0).round().toString());
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('إغلاق الصندوق اليومي'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('المبلغ المتوقع في الدرج: ${CurrencyFormatter.format(_zReport?.expectedDrawerCash ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: countCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(labelText: 'المبلغ الفعلي بعد الجرد (دج) *'),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final actual = double.tryParse(countCtrl.text.trim()) ?? 0.0;
                                          await reportProv.closeCashRegister(actual);
                                          Navigator.of(ctx).pop(true);
                                        },
                                        child: const Text('إغلاق الصندوق'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) _loadData();
                              },
                              child: const Text('إغلاق الصندوق'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Z-Report Header Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('تقرير الإغلاق المالي (Z-Report)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Icon(Icons.analytics_outlined, color: Colors.white),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي المبيعات:', style: TextStyle(color: Colors.white70)),
                            Text(
                              CurrencyFormatter.format(_zReport?.totalSales ?? 0),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('عدد الفواتير:', style: TextStyle(color: Colors.white70)),
                            Text('${_zReport?.totalInvoices ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('صافي الربح التقديري اليوم:', style: TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(
                              CurrencyFormatter.format(_zReport?.netProfit ?? 0),
                              style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Breakdown Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'مبيعات الكاش',
                          value: CurrencyFormatter.format(_zReport?.cashSales ?? 0),
                          icon: Icons.payments,
                          color: AppColors.cashColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'مبيعات الكريدي',
                          value: CurrencyFormatter.format(_zReport?.creditSales ?? 0),
                          icon: Icons.pending_actions,
                          color: AppColors.creditColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'ديون تم تحصيلها',
                          value: CurrencyFormatter.format(_zReport?.debtsCollected ?? 0),
                          icon: Icons.arrow_downward,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'إجمالي المصاريف',
                          value: CurrencyFormatter.format(_zReport?.totalExpenses ?? 0),
                          icon: Icons.money_off,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Expenses Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سجل المصاريف اليومية',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddExpenseDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('إضافة مصروف'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (reportProv.expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('لم يتم تسجيل أي مصاريف اليوم')),
                    )
                  else
                    ...reportProv.expenses.map((e) {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.receipt, color: Colors.white, size: 20),
                          ),
                          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(e.category),
                          trailing: Text(
                            '-${CurrencyFormatter.format(e.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 14),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
