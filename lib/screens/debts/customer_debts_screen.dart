import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer.dart';
import '../../providers/customer_debt_provider.dart';

class CustomerDebtsScreen extends StatefulWidget {
  const CustomerDebtsScreen({super.key});

  @override
  State<CustomerDebtsScreen> createState() => _CustomerDebtsScreenState();
}

class _CustomerDebtsScreenState extends State<CustomerDebtsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerDebtProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final debtCtrl = TextEditingController(text: '0');
    final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة زبون كريدي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم *')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            const SizedBox(height: 8),
            TextField(controller: debtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رصيد دين سابق (دج)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await debtProv.addCustomer(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  initialDebt: double.tryParse(debtCtrl.text.trim()) ?? 0.0,
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Customer customer) {
    final amountCtrl = TextEditingController(text: customer.currentDebt.round().toString());
    final notesCtrl = TextEditingController();
    final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسديد دين: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي الدين الحالي: ${CurrencyFormatter.format(customer.currentDebt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع (دج) *', prefixIcon: Icon(Icons.payments)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amount > 0) {
                await debtProv.recordPayment(
                  customerId: customer.id!,
                  paymentAmount: amount,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل دفعة السداد بنجاح ✓')),
                  );
                }
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('تأكيد التسديد'),
          ),
        ],
      ),
    );
  }

  void _showCustomerStatement(Customer customer) async {
    final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);
    final txns = await debtProv.getCustomerTransactions(customer.id!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('كشف حساب: ${customer.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('الدين الحالي: ${CurrencyFormatter.format(customer.currentDebt)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.creditColor)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const Divider(),
              Expanded(
                child: txns.isEmpty
                    ? const Center(child: Text('لا توجد حركات مسجلة لهذا الزبون'))
                    : ListView.builder(
                        itemCount: txns.length,
                        itemBuilder: (ctx, i) {
                          final t = txns[i];
                          final isPayment = t['type'] == 'debt_payment';
                          final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPayment ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15),
                              child: Icon(
                                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isPayment ? AppColors.success : AppColors.danger,
                              ),
                            ),
                            title: Text(
                              isPayment ? 'تسديد دفعة نقداً' : 'شراء بالكريدي',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.tryParse(t['created_at']) ?? DateTime.now())}\nالدين بعد العملية: ${CurrencyFormatter.format(t['new_debt'])}',
                            ),
                            trailing: Text(
                              '${isPayment ? "-" : "+"}${CurrencyFormatter.format(amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPayment ? AppColors.success : AppColors.danger,
                                fontSize: 14,
                              ),
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
    final debtProv = Provider.of<CustomerDebtProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ديون الزبائن (الكريدي)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'إضافة زبون جديد',
            onPressed: _showAddCustomerDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Debts Banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFF57C00)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي ديون السوق في ذمة الزبائن', style: TextStyle(color: Colors.white, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('المبالغ المنتظر تحصيلها', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(debtProv.totalDebts),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'بحث عن زبون بالاسم أو الهاتف...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => debtProv.loadCustomers(query: val),
            ),
          ),
          const SizedBox(height: 8),

          // Customers List
          Expanded(
            child: debtProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : debtProv.customers.isEmpty
                    ? const Center(child: Text('لا يوجد زبائن مسجلين'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: debtProv.customers.length,
                        itemBuilder: (context, i) {
                          final c = debtProv.customers[i];
                          return Card(
                            child: ListTile(
                              onTap: () => _showCustomerStatement(c),
                              leading: CircleAvatar(
                                backgroundColor: c.currentDebt > 0 ? AppColors.creditColor.withOpacity(0.15) : AppColors.success.withOpacity(0.15),
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0] : 'ز',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: c.currentDebt > 0 ? AppColors.creditColor : AppColors.success,
                                  ),
                                ),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c.phone ?? 'بدون هاتف'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(c.currentDebt),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: c.currentDebt > 0 ? AppColors.creditColor : AppColors.success,
                                        ),
                                      ),
                                      Text(c.currentDebt > 0 ? 'مستحق' : 'خالص ✓', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  if (c.currentDebt > 0) ...[
                                    IconButton(
                                      icon: const Icon(Icons.payment, color: AppColors.success),
                                      tooltip: 'تسديد دفعة',
                                      onPressed: () => _showPaymentDialog(c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Color(0xFF25D366)),
                                      tooltip: 'تذكير واتساب',
                                      onPressed: () => CustomerDebtProvider.sendDebtReminderWhatsApp(c),
                                    ),
                                  ],
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
