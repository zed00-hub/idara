import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  final ImagePicker _picker = ImagePicker();

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: AppColors.primaryIndigo),
            SizedBox(width: 8),
            Text('إضافة مورد جملة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المورد *')),
            const SizedBox(height: 10),
            TextField(controller: compCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة / العلامة (مثلاً: كانديا، كوكاكولا)')),
            const SizedBox(height: 10),
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
                if (mounted) Navigator.of(ctx).pop();
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
    final notesCtrl = TextEditingController();
    File? selectedImage;
    final supProv = Provider.of<SupplierProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.wholesaleColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'فاتورة شراء: ${supplier.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: invNumCtrl,
                  decoration: const InputDecoration(labelText: 'رقم فاتورة المورد (اختياري)', prefixIcon: Icon(Icons.tag)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: totalCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ الفاتورة الإجمالي (دج) *', prefixIcon: Icon(Icons.payments_outlined)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: paidCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع كاش الآن (دج) *', prefixIcon: Icon(Icons.money)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات حول البضاعة', prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 14),

                // Photo attachment section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.wholesaleColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.wholesaleColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.camera_alt, color: AppColors.wholesaleColor, size: 20),
                              SizedBox(width: 8),
                              Text('تصوير وصل الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          if (selectedImage != null)
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                              onPressed: () => setDlgState(() => selectedImage = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            selectedImage!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final XFile? photo = await _picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 85,
                                  );
                                  if (photo != null) {
                                    setDlgState(() => selectedImage = File(photo.path));
                                  }
                                },
                                icon: const Icon(Icons.camera, size: 18),
                                label: const Text('الكاميرا', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final XFile? photo = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (photo != null) {
                                    setDlgState(() => selectedImage = File(photo.path));
                                  }
                                },
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('المعرض', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final total = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
                final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;

                if (total > 0) {
                  String? savedImagePath;
                  if (selectedImage != null) {
                    try {
                      final appDir = await getApplicationDocumentsDirectory();
                      final filename = 'sup_inv_${DateTime.now().millisecondsSinceEpoch}${p.extension(selectedImage!.path)}';
                      final targetFile = File(p.join(appDir.path, filename));
                      await selectedImage!.copy(targetFile.path);
                      savedImagePath = targetFile.path;
                    } catch (_) {}
                  }

                  await supProv.recordSupplierInvoice(
                    supplierId: supplier.id!,
                    supplierName: supplier.name,
                    totalAmount: total,
                    paidAmount: paid,
                    invoiceNumber: invNumCtrl.text.trim().isEmpty ? null : invNumCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    imagePath: savedImagePath,
                  );

                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ تم حفظ فاتورة المورد وصورتها بنجاح'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ الفاتورة والصورة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayDebtDialog(Supplier supplier) {
    final amountCtrl = TextEditingController(text: supplier.currentDebt.round().toString());
    final supProv = Provider.of<SupplierProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تسديد مستحقات للمورد: ${supplier.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الدين الواجب سداده:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    CurrencyFormatter.format(supplier.currentDebt),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.danger),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع (دج) *', prefixIcon: Icon(Icons.payments)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amount > 0) {
                await supProv.paySupplierDebt(supplierId: supplier.id!, amount: amount);
                if (mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('تأكيد التسديد'),
          ),
        ],
      ),
    );
  }

  void _showSupplierInvoicesModal(Supplier supplier) async {
    final supProv = Provider.of<SupplierProvider>(context, listen: false);
    final invoices = await supProv.getSupplierInvoices(supplier.id!);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                    Text('سجل فواتير: ${supplier.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(supplier.company ?? 'مورد مستقل', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showAddInvoiceDialog(supplier);
                  },
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: const Text('تصوير فاتورة جديدة', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.wholesaleColor),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: invoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('لا توجد فواتير مشتريات مسجلة لهذا المورد'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final inv = invoices[i];
                        final hasImage = inv['image_path'] != null && inv['image_path'].toString().isNotEmpty;
                        final date = DateTime.tryParse(inv['created_at'] ?? '') ?? DateTime.now();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: hasImage
                              ? GestureDetector(
                                  onTap: () => _openImageViewer(File(inv['image_path'])),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      children: [
                                        Image.file(
                                          File(inv['image_path']),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.broken_image, size: 20),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.wholesaleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.receipt, color: AppColors.wholesaleColor, size: 24),
                                ),
                          title: Text(
                            'فاتورة: ${inv['invoice_number'] ?? 'بدون رقم'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy/MM/dd').format(date)} • مدفوع: ${CurrencyFormatter.format(inv['paid_amount'])}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(inv['total_amount']),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.wholesaleColor),
                              ),
                              if ((inv['remaining_debt'] as num? ?? 0) > 0)
                                Text(
                                  'متبقي: ${CurrencyFormatter.format(inv['remaining_debt'])}',
                                  style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(File imageFile) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(imageFile),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supProv = Provider.of<SupplierProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.wholesaleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping, color: AppColors.wholesaleColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الموردين وفواتير الشراء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('تصوير الفواتير ومتابعة الديون', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.wholesaleColor),
            tooltip: 'إضافة مورد',
            onPressed: _showAddSupplierDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Supplier Debts Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.wholesaleColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي مستحقات الموردين علينا', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      SizedBox(height: 4),
                      Text('الديون الواجب سدادها لشركات التوزيع', style: TextStyle(fontSize: 11, color: Colors.white60)),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(supProv.totalSupplierDebts),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Suppliers List
          Expanded(
            child: supProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : supProv.suppliers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لا يوجد موردين مسجلين', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: supProv.suppliers.length,
                        itemBuilder: (context, i) {
                          final s = supProv.suppliers[i];
                          return Card(
                            child: ListTile(
                              onTap: () => _showSupplierInvoicesModal(s),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.wholesaleColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.local_shipping, color: AppColors.wholesaleColor, size: 22),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                '${s.company ?? "موزع مستقل"} • ${s.phone ?? "بدون هاتف"}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
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
                                      Text(
                                        s.currentDebt > 0 ? 'مستحق له' : 'خالص ✓',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: s.currentDebt > 0 ? Colors.red : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.add_a_photo_outlined, color: AppColors.wholesaleColor, size: 22),
                                    tooltip: 'تصوير فاتورة شراء',
                                    onPressed: () => _showAddInvoiceDialog(s),
                                  ),
                                  if (s.currentDebt > 0)
                                    IconButton(
                                      icon: const Icon(Icons.payment, color: AppColors.success, size: 22),
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
