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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            const SizedBox(height: 10),
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

  void _onDeleteExpense(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text('هل أنت متأكد من حذف مصروف "$title"؟'),
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
      await Provider.of<FinancialReportProvider>(context, listen: false).deleteExpense(id);
      _loadData();
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل مصروف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'بيان المصروف (السبب) *')),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (دج) *')),
              const SizedBox(height: 10),
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
    final z = _zReport;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cash Register Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: register != null ? AppColors.primaryGradient : null,
                      color: register == null ? Colors.amber.shade50 : null,
                      borderRadius: BorderRadius.circular(16),
                      border: register == null ? Border.all(color: Colors.amber.shade300) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: register != null ? Colors.white.withOpacity(0.2) : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            register != null ? Icons.lock_open : Icons.lock_outline,
                            size: 26,
                            color: register != null ? Colors.white : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                register != null ? 'صندوق الكاش مفتوح حالياً' : 'الصندوق مغلق',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: register != null ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                register != null
                                    ? 'رصيد الافتتاح: ${CurrencyFormatter.format(register.openingAmount)}'
                                    : 'قم بفتح الصندوق لبدء دورة العمل اليومية',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: register != null ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: register == null ? _showOpenRegisterDialog : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryIndigo,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(register == null ? 'فتح الصندوق' : 'نشط'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // KPI 4 Cards Grid
                  if (z != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'إجمالي المبيعات',
                            value: CurrencyFormatter.format(z.totalSales),
                            icon: Icons.payments_outlined,
                            color: AppColors.primaryIndigo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'صافي الأرباح التقديرية',
                            value: CurrencyFormatter.format(z.netProfit),
                            icon: Icons.trending_up,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'المحصل نقداً بالدرج',
                            value: CurrencyFormatter.format(z.cashSales),
                            icon: Icons.account_balance_wallet_outlined,
                            color: AppColors.accentDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'مبيعات الكريدي (ديون)',
                            value: CurrencyFormatter.format(z.creditSales),
                            icon: Icons.hourglass_bottom,
                            color: AppColors.creditColor,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Expenses Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مصاريف المحل اليومية',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _showAddExpenseDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('تسجيل مصروف'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (reportProv.expenses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(child: Text('لا توجد مصاريف مسجلة لليوم')),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reportProv.expenses.length,
                      itemBuilder: (ctx, i) {
                        final exp = reportProv.expenses[i];
                        return Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.money_off, color: AppColors.danger, size: 18),
                            ),
                            title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(exp.category, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '-${CurrencyFormatter.format(exp.amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                  tooltip: 'حذف المصروف',
                                  onPressed: () {
                                    if (exp.id != null) _onDeleteExpense(exp.id!, exp.title);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
