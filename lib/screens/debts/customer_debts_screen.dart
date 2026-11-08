import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer.dart';
import '../../providers/customer_debt_provider.dart';
import '../../widgets/app_drawer.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: AppColors.primaryIndigo),
            SizedBox(width: 8),
            Text('إضافة زبون كريدي'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الزبون *')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            const SizedBox(height: 10),
            TextField(controller: debtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رصيد دين سابق إن وجد (دج)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final nav = Navigator.of(ctx);
                await debtProv.addCustomer(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  initialDebt: double.tryParse(debtCtrl.text.trim()) ?? 0.0,
                );
                if (mounted) nav.pop();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Customer customer) {
    final amountCtrl = TextEditingController(
      text: customer.currentDebt > 0 ? customer.currentDebt.round().toString() : '',
    );
    final notesCtrl = TextEditingController();
    final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تسديد دين: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (customer.currentDebt < 0
                        ? const Color(0xFF0D9488)
                        : (customer.currentDebt > 0 ? AppColors.creditColor : AppColors.success))
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    customer.currentDebt < 0
                        ? 'رصيد التسبيق الحالي:'
                        : (customer.currentDebt > 0 ? 'إجمالي الدين الحالي:' : 'حالة الحساب:'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    customer.currentDebt < 0
                        ? '+${CurrencyFormatter.format(-customer.currentDebt)}'
                        : (customer.currentDebt > 0 ? CurrencyFormatter.format(customer.currentDebt) : 'خالص ✅'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: customer.currentDebt < 0
                          ? const Color(0xFF0D9488)
                          : (customer.currentDebt > 0 ? AppColors.creditColor : AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع (دج) *',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظة (دفعة نقداً، تحويل...)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;

              // If payment exceeds current debt, request confirmation to record difference as advance
              if (customer.currentDebt > 0 && amt > customer.currentDebt) {
                final excess = amt - customer.currentDebt;
                final confirmExcess = await showDialog<bool>(
                  context: context,
                  builder: (cCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryIndigo),
                        SizedBox(width: 8),
                        Text('تأكيد رصيد تسبيق إضافي'),
                      ],
                    ),
                    content: Text(
                      'المبلغ المدفوع (${CurrencyFormatter.format(amt)}) أكبر من الدين الحالي (${CurrencyFormatter.format(customer.currentDebt)}) بمقدار ${CurrencyFormatter.format(excess)}.\n\n'
                      'هل تريد تسجيل مبلغ ${CurrencyFormatter.format(excess)} كرصيد إضافي (تسبيق لصالح الزبون)؟',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(cCtx).pop(false),
                        child: const Text('تعديل المبلغ'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(cCtx).pop(true),
                        child: const Text('نعم، حفظ التسبيق'),
                      ),
                    ],
                  ),
                );
                if (confirmExcess != true) return;
              }

              await debtProv.recordPayment(
                customerId: customer.id!,
                paymentAmount: amt,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              );
              if (mounted) {
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تسجيل الدفعة وتحديث رصيد الزبون'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('تأكيد القبض'),
          ),
        ],
      ),
    );
  }

  void _showRefundAdvanceDialog(Customer customer) {
    final availableAdvance = -customer.currentDebt;
    final amountCtrl = TextEditingController(text: availableAdvance.round().toString());
    final notesCtrl = TextEditingController(text: 'إرجاع تسبيق نقداً');
    final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('رد تسبيق: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رصيد التسبيق المتاح:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '+${CurrencyFormatter.format(availableAdvance)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D9488)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المراد إرجاعه نقداً (دج) *',
                prefixIcon: Icon(Icons.money_off_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0 || amt > availableAdvance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ يرجى إدخال مبلغ صحيح لا يتجاوز رصيد التسبيق المتاح'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await debtProv.refundAdvance(
                customerId: customer.id!,
                refundAmount: amt,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              );

              if (!mounted) return;
              nav.pop();
              if (success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم إرجاع المبلغ نقداً وتحديث رصيد الزبون والصندوق'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('تأكيد رد التسبيق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editCustomerDialog(Customer customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone ?? '');
    final debtCtrl = TextEditingController(text: customer.currentDebt.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: customer.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات الزبون'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الزبون *')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            const SizedBox(height: 10),
            TextField(
              controller: debtCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'الرصيد المالي الحالي (دج)',
                helperText: 'موجب = دين عليه، سالب = تسبيق لصالحه',
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final parsedDebt = double.tryParse(debtCtrl.text.trim()) ?? customer.currentDebt;
              final updated = customer.copyWith(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                currentDebt: parsedDebt,
                notes: notesCtrl.text.trim(),
              );
              final nav = Navigator.of(ctx);
              final rootNav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await Provider.of<CustomerDebtProvider>(context, listen: false).updateCustomer(updated);
              if (mounted) {
                nav.pop();
                rootNav.pop(); // close sheet
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ تم تعديل بيانات الزبون بنجاح'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomerDialog(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الزبون'),
        content: Text('هل أنت متأكد من حذف الزبون "${customer.name}" وكافة سجل دفعاته؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف نهائياً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final rootNav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await Provider.of<CustomerDebtProvider>(context, listen: false).deleteCustomer(customer.id!);
      if (!mounted) return;
      rootNav.pop(); // close sheet
      messenger.showSnackBar(
        const SnackBar(content: Text('✅ تم حذف الزبون بنجاح'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showStatementModal(Customer customer) async {
    final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);
    final history = await debtProv.getCustomerTransactions(customer.id!);

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (customer.phone != null && customer.phone!.isNotEmpty)
                        Text(customer.phone!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (customer.currentDebt < 0
                                  ? const Color(0xFF0D9488)
                                  : (customer.currentDebt > 0 ? AppColors.creditColor : AppColors.success))
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          customer.currentDebt < 0
                              ? 'تسبيق: +${CurrencyFormatter.format(-customer.currentDebt)}'
                              : (customer.currentDebt > 0
                                  ? 'الدين: ${CurrencyFormatter.format(customer.currentDebt)}'
                                  : 'خالص ✅'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: customer.currentDebt < 0
                                ? const Color(0xFF0D9488)
                                : (customer.currentDebt > 0 ? AppColors.creditColor : AppColors.success),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryIndigo),
                        tooltip: 'تعديل بيانات الزبون',
                        onPressed: () => _editCustomerDialog(customer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                        tooltip: 'حذف الزبون',
                        onPressed: () => _deleteCustomerDialog(customer),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: customer.currentDebt < 0
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showRefundAdvanceDialog(customer);
                            },
                            icon: const Icon(Icons.keyboard_return_rounded, size: 18, color: Colors.white),
                            label: const Text('رد التسبيق نقداً', style: TextStyle(color: Colors.white)),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showPaymentDialog(customer);
                            },
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text('تسديد دفعة'),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        CustomerDebtProvider.sendDebtReminderWhatsApp(customer);
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('كشف واتساب'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('سجل المعاملات والدفعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('لا توجد معاملات مسجلة'))
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final tx = history[i];
                          final isPayment = tx['type'] == 'debt_payment' || tx['type'] == 'payment';
                          final date = DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isPayment ? AppColors.success : AppColors.creditColor).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isPayment ? AppColors.success : AppColors.creditColor,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              isPayment ? 'تسديد دفعة' : (tx['notes'] ?? 'شراء بالدين'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: Text(
                              '${isPayment ? '-' : '+'}${CurrencyFormatter.format(tx['amount'])}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isPayment ? AppColors.success : AppColors.creditColor,
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
    final customers = debtProv.customers;

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
                color: AppColors.creditColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_alt, color: AppColors.creditColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ديون الزبائن (الكريدي)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('كشوف الحسابات والتسديد', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.creditColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('زبون جديد', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Total Debts Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.creditColor.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي الديون المعلقة في السوق', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(debtProv.totalDebts),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (debtProv.totalAdvances > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'تسبيقات للزبائن: +${CurrencyFormatter.format(debtProv.totalAdvances)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${customers.length} زبون',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'بحث باسم الزبون أو الهاتف...',
                prefixIcon: Icon(Icons.search, color: AppColors.creditColor),
              ),
              onChanged: (val) => debtProv.loadCustomers(query: val),
            ),
          ),
          const SizedBox(height: 6),

          // Customers List
          Expanded(
            child: debtProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_outline, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لا يوجد زبائن كريدي مسجلين', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: customers.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemBuilder: (context, i) {
                          final cust = customers[i];
                          return Card(
                            child: ListTile(
                              onTap: () => _showStatementModal(cust),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (cust.currentDebt < 0 ? const Color(0xFF0D9488) : AppColors.creditColor).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    cust.name.isNotEmpty ? cust.name[0] : 'ز',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: cust.currentDebt < 0 ? const Color(0xFF0D9488) : AppColors.creditColor,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                (cust.phone != null && cust.phone!.isNotEmpty) ? cust.phone! : 'بدون هاتف',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    cust.currentDebt < 0
                                        ? '+${CurrencyFormatter.format(-cust.currentDebt)}'
                                        : (cust.currentDebt > 0
                                            ? CurrencyFormatter.format(cust.currentDebt)
                                            : '0 دج'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: cust.currentDebt < 0
                                          ? const Color(0xFF0D9488)
                                          : (cust.currentDebt > 0 ? AppColors.creditColor : AppColors.success),
                                    ),
                                  ),
                                  Text(
                                    cust.currentDebt < 0
                                        ? 'تسبيق للزبون 👍'
                                        : (cust.currentDebt > 0 ? 'مطلوب دين ⏳' : 'خالص ✅'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cust.currentDebt < 0
                                          ? const Color(0xFF0D9488)
                                          : (cust.currentDebt > 0 ? Colors.red : AppColors.success),
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
