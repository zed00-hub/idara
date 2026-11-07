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
  String _filter = 'all'; // all, cash, credit, today

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final db = await DBHelper.instance.database;

    final invoiceMaps = await db.query('invoices', orderBy: 'id DESC', limit: 120);
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

  List<Invoice> get _filteredInvoices {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    switch (_filter) {
      case 'today':
        return _invoices.where((inv) => inv.createdAt.startsWith(todayStr)).toList();
      case 'cash':
        return _invoices.where((inv) => inv.paymentType == PaymentType.cash).toList();
      case 'credit':
        return _invoices.where((inv) => inv.paymentType == PaymentType.credit || inv.paymentType == PaymentType.partial).toList();
      default:
        return _invoices;
    }
  }

  double get _todayTotalRevenue {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _invoices
        .where((inv) => inv.createdAt.startsWith(todayStr))
        .fold(0.0, (sum, inv) => sum + inv.paidAmount);
  }

  void _showInvoiceDetails(Invoice invoice) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryIndigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: AppColors.primaryIndigo, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'فاتورة ${invoice.invoiceNumber}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.tryParse(invoice.createdAt) ?? DateTime.now())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (invoice.customerName != null)
                    Text('الزبون: ${invoice.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: invoice.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = invoice.items[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${item.quantity.toInt()} × ${item.unitPrice.round()} دج (${item.priceType == PriceType.wholesale ? 'جملة' : 'تجزئة'})'),
                      trailing: Text(CurrencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المبلغ الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    CurrencyFormatter.format(invoice.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaryIndigo),
                  ),
                ],
              ),
              if (invoice.remainingDebt > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المسجل كدين:', style: TextStyle(color: AppColors.creditColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        CurrencyFormatter.format(invoice.remainingDebt),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.creditColor),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => PrintService.printReceipt(invoice),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('طباعة حرارية'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => PrintService.shareInvoicePdf(invoice),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('واتساب PDF'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredInvoices;

    return Scaffold(
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
                color: AppColors.primaryIndigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.primaryIndigo, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجل الفواتير والمبيعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('أرشيف المبيعات والوصولات', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryIndigo),
            tooltip: 'تحديث',
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Today's Summary Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryIndigo.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مبيعات اليوم المحصلة', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(_todayTotalRevenue),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_invoices.length} فاتورة',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('اليوم 📅', 'today'),
                const SizedBox(width: 6),
                _buildFilterChip('نقدي 💵', 'cash'),
                const SizedBox(width: 6),
                _buildFilterChip('كريدي ⏳', 'credit'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Invoices List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لا توجد فواتير مطابقة', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemBuilder: (context, i) {
                          final inv = filtered[i];
                          final date = DateTime.tryParse(inv.createdAt) ?? DateTime.now();
                          final isCredit = inv.paymentType == PaymentType.credit || inv.paymentType == PaymentType.partial;

                          return Card(
                            child: ListTile(
                              onTap: () => _showInvoiceDetails(inv),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (isCredit ? AppColors.creditColor : AppColors.cashColor).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isCredit ? Icons.hourglass_top_outlined : Icons.payments_outlined,
                                  color: isCredit ? AppColors.creditColor : AppColors.cashColor,
                                  size: 22,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    inv.invoiceNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(inv.totalAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryIndigo),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${DateFormat('MM/dd HH:mm').format(date)} • ${inv.items.length} صنف',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isCredit ? AppColors.creditColor : AppColors.cashColor).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCredit ? 'كريدي' : 'نقدي',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isCredit ? AppColors.creditColor : AppColors.cashColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.print_outlined, size: 20, color: AppColors.primaryIndigo),
                                onPressed: () => PrintService.printReceipt(inv),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryIndigo : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
