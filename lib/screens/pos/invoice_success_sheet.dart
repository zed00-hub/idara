import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/print_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/invoice.dart';

class InvoiceSuccessSheet extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onNewSale;

  const InvoiceSuccessSheet({
    super.key,
    required this.invoice,
    required this.onNewSale,
  });

  static Future<void> show(BuildContext context, {required Invoice invoice, required VoidCallback onNewSale}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InvoiceSuccessSheet(invoice: invoice, onNewSale: onNewSale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 52),
          ),
          const SizedBox(height: 12),

          const Text(
            'تم تسجيل البيع بنجاح!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'رقم الفاتورة: ${invoice.invoiceNumber}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Total card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المبلغ الإجمالي:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  CurrencyFormatter.format(invoice.totalAmount),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),

          if (invoice.changeGiven > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الفكة المرجعة للزبون (مقربة 5 دج):', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    CurrencyFormatter.format(invoice.changeGiven),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accentDark),
                  ),
                ],
              ),
            ),
          ],

          if (invoice.remainingDebt > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مسجل كدين على: ${invoice.customerName ?? "زبون"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    CurrencyFormatter.format(invoice.remainingDebt),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons: Thermal Print, WhatsApp, New Sale
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => PrintService.printReceipt(invoice),
                  icon: const Icon(Icons.print),
                  label: const Text('طباعة حرارية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => PrintService.shareInvoiceViaWhatsApp(invoice),
                  icon: const Icon(Icons.share),
                  label: const Text('واتساب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onNewSale();
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('عملية بيع جديدة'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
