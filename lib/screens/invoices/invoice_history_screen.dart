import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/db_helper.dart';
import '../../core/services/print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart_item.dart';
import '../../models/invoice.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final db = await DBHelper.instance.database;

    final invoiceMaps = await db.query('invoices', orderBy: 'id DESC', limit: 100);
    final List<Invoice> list = [];

    for (var invMap in invoiceMaps) {
      final itemsMaps = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invMap['id']],
      );
      final items = itemsMaps.map((item) => CartItem.fromMap(item)).toList();
      list.add(Invoice.fromMap(invMap, items: items));
    }

    setState(() {
      _invoices = list;
      _isLoading = false;
    });
  }

  void _showInvoiceDetails(Invoice invoice) {
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
                  Text(
                    'تفاصيل ${invoice.invoiceNumber}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.tryParse(invoice.createdAt) ?? DateTime.now())}'),
                  if (invoice.customerName != null) Text('الزبون: ${invoice.customerName}'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: invoice.items.length,
                  itemBuilder: (ctx, i) {
                    final item = invoice.items[i];
                    return ListTile(
                      dense: true,
                      title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantity} × ${item.unitPrice.round()} دج'),
                      trailing: Text(CurrencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المجموع الإجمالي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(CurrencyFormatter.format(invoice.totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PrintService.printReceipt(invoice),
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PrintService.shareInvoiceViaWhatsApp(invoice),
                      icon: const Icon(Icons.share),
                      label: const Text('واتساب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الفواتير والمبيعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('لا توجد فواتير مسجلة بعد', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _invoices.length,
                  itemBuilder: (context, i) {
                    final inv = _invoices[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _showInvoiceDetails(inv),
                        leading: CircleAvatar(
                          backgroundColor: inv.paymentType == PaymentType.cash
                              ? AppColors.cashColor.withOpacity(0.15)
                              : inv.paymentType == PaymentType.credit
                                  ? AppColors.creditColor.withOpacity(0.15)
                                  : AppColors.partialColor.withOpacity(0.15),
                          child: Icon(
                            inv.paymentType == PaymentType.cash
                                ? Icons.payments_outlined
                                : inv.paymentType == PaymentType.credit
                                    ? Icons.pending_actions
                                    : Icons.pie_chart_outline,
                            color: inv.paymentType == PaymentType.cash
                                ? AppColors.cashColor
                                : inv.paymentType == PaymentType.credit
                                    ? AppColors.creditColor
                                    : AppColors.partialColor,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              CurrencyFormatter.format(inv.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Text(DateFormat('MM/dd HH:mm').format(DateTime.tryParse(inv.createdAt) ?? DateTime.now())),
                            if (inv.customerName != null) ...[
                              const SizedBox(width: 8),
                              Text('• ${inv.customerName}'),
                            ],
                            const Spacer(),
                            Text(
                              inv.paymentType == PaymentType.cash
                                  ? 'نقدي'
                                  : inv.paymentType == PaymentType.credit
                                      ? 'كريدي'
                                      : 'جزئي',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: inv.paymentType == PaymentType.cash
                                    ? AppColors.cashColor
                                    : inv.paymentType == PaymentType.credit
                                        ? AppColors.creditColor
                                        : AppColors.partialColor,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      ),
                    );
                  },
                ),
    );
  }
}
