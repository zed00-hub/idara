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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Success Animated Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppColors.accent, size: 54),
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
          const SizedBox(height: 18),

          // Total card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المبلغ الإجمالي:', style: TextStyle(fontSize: 14, color: Colors.white70)),
                Text(
                  CurrencyFormatter.format(invoice.totalAmount),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),

          if (invoice.changeGiven > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الفكة المرجعة للزبون (مقربة 5 دج):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    CurrencyFormatter.format(invoice.changeGiven),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.accentDark),
                  ),
                ],
              ),
            ),
          ],

          if (invoice.remainingDebt > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.creditColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.creditColor, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المسجل كدين على (${invoice.customerName ?? 'الزبون'}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    CurrencyFormatter.format(invoice.remainingDebt),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.creditColor),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Print & Share Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await PrintService.printReceipt(invoice);
                  },
                  icon: const Icon(Icons.print, size: 20),
                  label: const Text('طباعة الوصل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await PrintService.shareInvoicePdf(invoice);
                  },
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('واتساب PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // New Sale button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onNewSale();
              },
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('بدء بيع جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
