import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../providers/customer_debt_provider.dart';
import '../../providers/pos_provider.dart';
import 'invoice_success_sheet.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CheckoutDialog(),
    );
  }

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentType _paymentType = PaymentType.cash;
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Customer? _selectedCustomer;
  double _customPaid = 0.0;

  @override
  void initState() {
    super.initState();
    final pos = Provider.of<POSProvider>(context, listen: false);
    _paidController.text = pos.netTotal.round().toString();
    _discountController.text = pos.discount > 0 ? pos.discount.round().toString() : '';
    _customPaid = pos.netTotal;
    _selectedCustomer = pos.selectedCustomer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerDebtProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  void dispose() {
    _paidController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onQuickCashSelected(num amount) {
    setState(() {
      _customPaid = amount.toDouble();
      _paidController.text = amount.round().toString();
    });
  }

  void _confirmCheckout() async {
    final pos = Provider.of<POSProvider>(context, listen: false);

    // Apply any discount entered
    final disc = double.tryParse(_discountController.text.trim()) ?? 0.0;
    pos.setDiscount(disc.clamp(0.0, pos.subtotal));

    final netTotal = pos.netTotal;

    if (_paymentType == PaymentType.credit || _paymentType == PaymentType.partial) {
      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ يرجى اختيار زبون مسجل لحفظ الدين (الكريدي)!'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    double paidAmount = double.tryParse(_paidController.text.trim()) ?? _customPaid;
    double changeGiven = 0.0;
    double remainingDebt = 0.0;

    if (_paymentType == PaymentType.cash) {
      if (paidAmount < netTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ المبلغ المستلم أقل من الإجمالي!'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      changeGiven = CurrencyFormatter.calculateRoundedChange(
        totalDue: netTotal,
        paidAmount: paidAmount,
      ).toDouble();
      paidAmount = netTotal; // Actual revenue
    } else if (_paymentType == PaymentType.credit) {
      paidAmount = 0.0;
      remainingDebt = netTotal;
    } else if (_paymentType == PaymentType.partial) {
      if (paidAmount < 0) paidAmount = 0.0;
      if (paidAmount >= netTotal) {
        _paymentType = PaymentType.cash;
        changeGiven = CurrencyFormatter.calculateRoundedChange(
          totalDue: netTotal,
          paidAmount: paidAmount,
        ).toDouble();
        paidAmount = netTotal;
        remainingDebt = 0.0;
      } else {
        remainingDebt = netTotal - paidAmount;
      }
    }

    pos.setSelectedCustomer(_selectedCustomer);
    final invoice = await pos.completeCheckout(
      paymentType: _paymentType,
      paidAmount: paidAmount,
      changeGiven: changeGiven,
      remainingDebt: remainingDebt,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    // Refresh CustomerDebtProvider so customer debts screen immediately reflects new balances
    if (mounted) {
      await Provider.of<CustomerDebtProvider>(context, listen: false).loadCustomers();
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Close checkout dialog

    if (invoice != null) {
      InvoiceSuccessSheet.show(
        context,
        invoice: invoice,
        onNewSale: () {},
      );
    }
  }

  void _showQuickAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة زبون سريع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم الزبون *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final debtProv = Provider.of<CustomerDebtProvider>(context, listen: false);
                final newCust = await debtProv.addCustomer(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                if (newCust != null && mounted) {
                  final matched = debtProv.customers.firstWhere(
                    (c) => c.id == newCust.id,
                    orElse: () => newCust,
                  );
                  setState(() => _selectedCustomer = matched);
                }
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<POSProvider>(context);
    final debtProv = Provider.of<CustomerDebtProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final netTotal = pos.netTotal;

    final roundedChange = _paymentType == PaymentType.cash
        ? CurrencyFormatter.calculateRoundedChange(totalDue: netTotal, paidAmount: _customPaid)
        : 0;

    final remainingDebt = (_paymentType == PaymentType.credit)
        ? netTotal
        : (_paymentType == PaymentType.partial && _customPaid < netTotal)
            ? (netTotal - _customPaid)
            : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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
                        child: const Icon(Icons.payment, color: AppColors.primaryIndigo, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'إتمام عملية البيع',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Subtotal & Discount row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المجموع الفرعي:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            CurrencyFormatter.format(pos.subtotal),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger),
                        decoration: InputDecoration(
                          labelText: 'تخفيض (دج)',
                          labelStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
                          prefixIcon: const Icon(Icons.discount_outlined, size: 16, color: AppColors.danger),
                          hintText: '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: AppColors.danger.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          final disc = double.tryParse(val.trim()) ?? 0.0;
                          pos.setDiscount(disc.clamp(0.0, pos.subtotal));
                          setState(() {
                            if (_paymentType == PaymentType.cash) {
                              _customPaid = pos.netTotal;
                              _paidController.text = pos.netTotal.round().toString();
                            } else if (_paymentType == PaymentType.partial) {
                              _customPaid = (pos.netTotal / 2).roundToDouble();
                              _paidController.text = _customPaid.round().toString();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Total banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الصافي المستحق:', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    Text(
                      CurrencyFormatter.format(netTotal),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Type Tabs (Cash, Credit, Partial)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildPaymentTab(
                      type: PaymentType.cash,
                      label: 'نقداً 💵',
                      activeColor: AppColors.cashColor,
                      isSelected: _paymentType == PaymentType.cash,
                      onTap: () {
                        setState(() {
                          _paymentType = PaymentType.cash;
                          _customPaid = netTotal;
                          _paidController.text = netTotal.round().toString();
                        });
                      },
                    ),
                    _buildPaymentTab(
                      type: PaymentType.credit,
                      label: 'كريدي ⏳',
                      activeColor: AppColors.creditColor,
                      isSelected: _paymentType == PaymentType.credit,
                      onTap: () {
                        setState(() {
                          _paymentType = PaymentType.credit;
                          _customPaid = 0;
                          _paidController.text = '0';
                        });
                      },
                    ),
                    _buildPaymentTab(
                      type: PaymentType.partial,
                      label: 'جزئي 💳',
                      activeColor: AppColors.partialColor,
                      isSelected: _paymentType == PaymentType.partial,
                      onTap: () {
                        setState(() {
                          _paymentType = PaymentType.partial;
                          _customPaid = (netTotal / 2).roundToDouble();
                          _paidController.text = _customPaid.round().toString();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Customer Selector (Visible if credit or partial, or optional for cash)
              if (_paymentType != PaymentType.cash || _selectedCustomer != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Customer>(
                        value: _selectedCustomer,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _paymentType != PaymentType.cash ? 'الزبون (إجباري للدين) *' : 'الزبون (اختياري)',
                          prefixIcon: const Icon(Icons.person),
                        ),
                        items: debtProv.customers.map((c) {
                          final debtText = c.currentDebt < 0
                              ? 'تسبيق: +${CurrencyFormatter.format(-c.currentDebt)}'
                              : (c.currentDebt > 0 ? 'دين: ${CurrencyFormatter.format(c.currentDebt)}' : 'بدون دين');
                          return DropdownMenuItem<Customer>(
                            value: c,
                            child: Text(
                              '${c.name} ($debtText)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (cust) => setState(() => _selectedCustomer = cust),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: AppColors.primaryIndigo),
                      tooltip: 'إضافة زبون جديد',
                      onPressed: _showQuickAddCustomerDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Cash Inputs (Only for Cash or Partial)
              if (_paymentType != PaymentType.credit) ...[
                TextField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _paymentType == PaymentType.cash ? 'المبلغ المستلم من الزبون (دج)' : 'المبلغ المدفوع الآن (دج)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _customPaid = double.tryParse(val.trim()) ?? 0.0;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Fast Cash Presets (Exact, 500, 1000, 2000, 5000)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: Text('تماماً (${netTotal.round()} دج)'),
                      onPressed: () => _onQuickCashSelected(netTotal),
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                    if (netTotal < 500)
                      ActionChip(
                        label: const Text('500 دج'),
                        onPressed: () => _onQuickCashSelected(500),
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                    if (netTotal < 1000)
                      ActionChip(
                        label: const Text('1000 دج'),
                        onPressed: () => _onQuickCashSelected(1000),
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                    if (netTotal < 2000)
                      ActionChip(
                        label: const Text('2000 دج'),
                        onPressed: () => _onQuickCashSelected(2000),
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                    ActionChip(
                      label: const Text('5000 دج'),
                      onPressed: () => _onQuickCashSelected(5000),
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Live Change Card with Algerian 5 DZD Rounding Rule!
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: roundedChange > 0
                        ? AppColors.accentLight.withOpacity(0.5)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: roundedChange > 0 ? AppColors.accent : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الفكة المرجعة للزبون:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            'مقربة لأقرب 5 دج تلقائياً (العملة الجزائرية)',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      Text(
                        '${roundedChange.round()} دج',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: roundedChange > 0 ? AppColors.accentDark : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Remaining Debt Preview (if credit or partial)
              if (remainingDebt > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.creditColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.creditColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المبلغ المسجل كدين (كريدي):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        CurrencyFormatter.format(remainingDebt),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.creditColor),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة على الفاتورة (اختياري)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _confirmCheckout,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('تأكيد البيع وطباعة الوصل', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentDark,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTab({
    required PaymentType type,
    required String label,
    required Color activeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
