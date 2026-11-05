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
  final TextEditingController _notesController = TextEditingController();
  Customer? _selectedCustomer;
  double _customPaid = 0.0;

  @override
  void initState() {
    super.initState();
    final pos = Provider.of<POSProvider>(context, listen: false);
    _paidController.text = pos.netTotal.round().toString();
    _customPaid = pos.netTotal;
    _selectedCustomer = pos.selectedCustomer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerDebtProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  void dispose() {
    _paidController.dispose();
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
    final netTotal = pos.netTotal;

    if (_paymentType == PaymentType.credit || _paymentType == PaymentType.partial) {
      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ يجب اختيار زبون مسجل لحفظ الدين (الكريدي)!'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    double paidAmount = _customPaid;
    double changeGiven = 0.0;
    double remainingDebt = 0.0;

    if (_paymentType == PaymentType.cash) {
      if (paidAmount < netTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ المبلغ المدفوع أقل من الإجمالي في الدفع النقدي!'),
            backgroundColor: AppColors.danger,
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
      if (paidAmount >= netTotal) {
        _paymentType = PaymentType.cash;
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
        title: const Text('إضافة زبون سريع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم الزبون *'),
            ),
            const SizedBox(height: 8),
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
                  setState(() => _selectedCustomer = newCust);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إتمام عملية البيع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),

              // Total banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ المطلوب:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.format(netTotal),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Type Selector (Cash, Credit, Partial)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('نقدي 💵')),
                      selected: _paymentType == PaymentType.cash,
                      selectedColor: AppColors.cashColor.withOpacity(0.2),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _paymentType = PaymentType.cash;
                            _customPaid = netTotal;
                            _paidController.text = netTotal.round().toString();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('كريدي ⏳')),
                      selected: _paymentType == PaymentType.credit,
                      selectedColor: AppColors.creditColor.withOpacity(0.2),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _paymentType = PaymentType.credit;
                            _customPaid = 0;
                            _paidController.text = '0';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('جزئي 💳')),
                      selected: _paymentType == PaymentType.partial,
                      selectedColor: AppColors.partialColor.withOpacity(0.2),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _paymentType = PaymentType.partial;
                            _customPaid = (netTotal / 2).roundToDouble();
                            _paidController.text = _customPaid.round().toString();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Selector (Visible if credit or partial, or optional for cash)
              if (_paymentType != PaymentType.cash || _selectedCustomer != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Customer>(
                        value: _selectedCustomer,
                        decoration: InputDecoration(
                          labelText: _paymentType != PaymentType.cash ? 'الزبون (إجباري للكريدي) *' : 'الزبون (اختياري)',
                          prefixIcon: const Icon(Icons.person),
                        ),
                        items: debtProv.customers.map((c) {
                          return DropdownMenuItem<Customer>(
                            value: c,
                            child: Text('${c.name} (دين سابق: ${c.currentDebt.round()} دج)'),
                          );
                        }).toList(),
                        onChanged: (cust) => setState(() => _selectedCustomer = cust),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: AppColors.primary),
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
                const SizedBox(height: 8),

                // Fast Cash Buttons (Algerian Banknotes: 500, 1000, 2000, Exact)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: Text('تماماً (${netTotal.round()} دج)'),
                      onPressed: () => _onQuickCashSelected(netTotal),
                    ),
                    if (netTotal < 500)
                      ActionChip(label: const Text('500 دج'), onPressed: () => _onQuickCashSelected(500)),
                    if (netTotal < 1000)
                      ActionChip(label: const Text('1,000 دج'), onPressed: () => _onQuickCashSelected(1000)),
                    if (netTotal < 2000)
                      ActionChip(label: const Text('2,000 دج'), onPressed: () => _onQuickCashSelected(2000)),
                    if (netTotal < 5000)
                      ActionChip(label: const Text('5,000 دج'), onPressed: () => _onQuickCashSelected(5000)),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Change Due / Remaining Debt Calculation Display
              if (_paymentType == PaymentType.cash && _customPaid >= netTotal) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الفكة المرجعة (مقربة 5 دج):', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${CurrencyFormatter.format(roundedChange)} (${roundedChange} دج)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentDark),
                      ),
                    ],
                  ),
                ),
              ],

              if (remainingDebt > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.creditColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.creditColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الدين المتبقي للكريدي:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(remainingDebt),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.creditColor),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Confirm Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirmCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'تأكيد وحفظ الفاتورة ✓',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
