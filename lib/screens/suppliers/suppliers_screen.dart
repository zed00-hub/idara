import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
    });
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final supProv = Provider.of<SupplierProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مورد جملة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المورد *')),
            const SizedBox(height: 8),
            TextField(controller: compCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة / العلامة')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await supProv.addSupplier(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  company: compCtrl.text.trim(),
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

  void _showAddInvoiceDialog(Supplier supplier) {
    final invNumCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final paidCtrl = TextEditingController();
    final supProv = Provider.of<SupplierProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل فاتورة شراء: ${supplier.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: invNumCtrl, decoration: const InputDecoration(labelText: 'رقم فاتورة المورد (اختياري)')),
            const SizedBox(height: 8),
            TextField(controller: totalCtrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ الفاتورة الإجمالي (دج) *')),
            const SizedBox(height: 8),
            TextField(controller: paidCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المدفوع كاش (دج) *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final total = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
              final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;

              if (total > 0) {
                await supProv.recordSupplierInvoice(
                  supplierId: supplier.id!,
                  supplierName: supplier.name,
                  totalAmount: total,
                  paidAmount: paid,
                  invoiceNumber: invNumCtrl.text.trim().isEmpty ? null : invNumCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('تسجيل الفاتورة'),
          ),
        ],
      ),
    );
  }

  void _showPayDebtDialog(Supplier supplier) {
    final amountCtrl = TextEditingController(text: supplier.currentDebt.round().toString());
    final supProv = Provider.of<SupplierProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسديد مستحقات للمورد: ${supplier.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الدين الحالي في ذمتنا: ${CurrencyFormatter.format(supplier.currentDebt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المدفوع (دج) *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amount > 0) {
                await supProv.paySupplierDebt(supplierId: supplier.id!, amount: amount);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('تأكيد التسديد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supProv = Provider.of<SupplierProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردين ومشتريات الجملة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'إضافة مورد',
            onPressed: _showAddSupplierDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Supplier Debts Banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF00897B)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي مستحقات الموردين علينا', style: TextStyle(color: Colors.white, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('الديون الواجب سدادها لشركات التوزيع', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(supProv.totalSupplierDebts),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Suppliers List
          Expanded(
            child: supProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : supProv.suppliers.isEmpty
                    ? const Center(child: Text('لا يوجد موردين مسجلين'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: supProv.suppliers.length,
                        itemBuilder: (context, i) {
                          final s = supProv.suppliers[i];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.local_shipping, color: Colors.white),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${s.company ?? "موزع مستقل"} • ${s.phone ?? "بدون هاتف"}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(s.currentDebt),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: s.currentDebt > 0 ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                      Text(s.currentDebt > 0 ? 'مستحق له' : 'خالص ✓', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.receipt, color: AppColors.primary),
                                    tooltip: 'تسجيل فاتورة شراء',
                                    onPressed: () => _showAddInvoiceDialog(s),
                                  ),
                                  if (s.currentDebt > 0)
                                    IconButton(
                                      icon: const Icon(Icons.payment, color: AppColors.success),
                                      tooltip: 'تسديد دفعة',
                                      onPressed: () => _showPayDebtDialog(s),
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
