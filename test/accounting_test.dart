import 'package:flutter_test/flutter_test.dart';
import 'package:ndmha/core/utils/currency_formatter.dart';

void main() {
  group('Algerian Dinar Currency & Rounding Tests', () {
    test('roundTo5DZD handles positive values accurately', () {
      expect(CurrencyFormatter.roundTo5DZD(11), 10);
      expect(CurrencyFormatter.roundTo5DZD(12), 10);
      expect(CurrencyFormatter.roundTo5DZD(13), 15);
      expect(CurrencyFormatter.roundTo5DZD(14), 15);
      expect(CurrencyFormatter.roundTo5DZD(15), 15);
      expect(CurrencyFormatter.roundTo5DZD(18), 20);
      expect(CurrencyFormatter.roundTo5DZD(0), 0);
    });

    test('roundTo5DZD handles negative values symmetrically', () {
      expect(CurrencyFormatter.roundTo5DZD(-11), -10);
      expect(CurrencyFormatter.roundTo5DZD(-12), -10);
      expect(CurrencyFormatter.roundTo5DZD(-13), -15);
      expect(CurrencyFormatter.roundTo5DZD(-14), -15);
      expect(CurrencyFormatter.roundTo5DZD(-15), -15);
      expect(CurrencyFormatter.roundTo5DZD(-18), -20);
    });

    test('calculateRoundedChange computes exact and rounded difference', () {
      final change = CurrencyFormatter.calculateRoundedChange(
        paidAmount: 200,
        totalDue: 188,
      );
      // exact: 12 -> rounded: 10
      expect(change, 10);

      final change2 = CurrencyFormatter.calculateRoundedChange(
        paidAmount: 500,
        totalDue: 483,
      );
      // exact: 17 -> rounded: 15
      expect(change2, 15);

      final changeUnderpaid = CurrencyFormatter.calculateRoundedChange(
        paidAmount: 100,
        totalDue: 150,
      );
      expect(changeUnderpaid, 0);
    });
  });

  group('Accounting & Valuation Math Tests', () {
    test('Gross profit and profit margin calculation with positive margin', () {
      const totalSales = 10000.0;
      const totalCost = 7500.0;
      const totalExpenses = 500.0;

      final grossProfit = totalSales - totalCost;
      final netProfit = grossProfit - totalExpenses;
      final profitMargin = totalCost > 0 ? (grossProfit / totalCost) * 100 : 0.0;

      expect(grossProfit, 2500.0);
      expect(netProfit, 2000.0);
      expect(profitMargin, closeTo(33.33, 0.01));
    });

    test('Gross profit accurately reflects negative margin (trading loss)', () {
      const totalSales = 5000.0;
      const totalCost = 6000.0;
      const totalExpenses = 400.0;

      final grossProfit = totalSales - totalCost;
      final netProfit = grossProfit - totalExpenses;
      final profitMargin = totalCost > 0 ? (grossProfit / totalCost) * 100 : 0.0;

      expect(grossProfit, -1000.0);
      expect(netProfit, -1400.0);
      expect(profitMargin, closeTo(-16.67, 0.01));
    });

    test('Effective discount clamping does not exceed subtotal', () {
      const subtotal = 150.0;
      const inputDiscount = 200.0;

      final effectiveDiscount = (inputDiscount > subtotal) ? subtotal : (inputDiscount < 0 ? 0.0 : inputDiscount);
      final netTotal = subtotal - effectiveDiscount;

      expect(effectiveDiscount, 150.0);
      expect(netTotal, 0.0);
    });

    test('Partial payment change calculation when paid amount exceeds net total', () {
      const netTotal = 340.0;
      const paidAmount = 400.0;

      final bool isFullOrOverpaid = paidAmount >= netTotal;
      final int change = isFullOrOverpaid 
          ? CurrencyFormatter.calculateRoundedChange(paidAmount: paidAmount, totalDue: netTotal)
          : 0;
      final double remainingDebt = isFullOrOverpaid ? 0.0 : (netTotal - paidAmount);

      expect(isFullOrOverpaid, isTrue);
      // exact change 60 -> rounded to 5 DZD is 60
      expect(change, 60);
      expect(remainingDebt, 0.0);
    });

    test('Partial payment for new customer accurately leaves remaining debt', () {
      const netTotal = 1415.0;
      const paidAmount = 415.0;

      final remainingDebt = netTotal - paidAmount;
      expect(remainingDebt, 1000.0);

      // Previous customer debt was 0.0 (new customer)
      const prevCustomerDebt = 0.0;
      final newCustomerDebt = prevCustomerDebt + remainingDebt;
      expect(newCustomerDebt, 1000.0);
    });

    test('Customer overpayment records advance / credit balance as negative debt', () {
      const prevDebt = 1000.0;
      const paymentAmount = 1500.0;

      // In double-entry retail accounting, debt - payment = new debt balance
      final newDebt = prevDebt - paymentAmount;

      // Expect -500.0 indicating a 500 DZD credit balance / advance in customer's favor
      expect(newDebt, -500.0);
      expect(newDebt < 0, isTrue);
      final advanceAmount = -newDebt;
      expect(advanceAmount, 500.0);
    });

    test('Advance credit balance is correctly offset by subsequent credit purchase', () {
      // Customer has 500 DZD advance (debt = -500.0)
      const currentDebt = -500.0;
      const newPurchaseDebt = 700.0;

      final updatedDebt = currentDebt + newPurchaseDebt;
      // -500 + 700 = 200 DZD owed to store
      expect(updatedDebt, 200.0);
    });

    test('Cancelled invoice exclusion from total sales revenue', () {
      final invoices = [
        {'id': 1, 'amount': 1500.0, 'is_cancelled': 0},
        {'id': 2, 'amount': 2200.0, 'is_cancelled': 1}, // cancelled
        {'id': 3, 'amount': 800.0, 'is_cancelled': 0},
      ];

      final totalActiveRevenue = invoices
          .where((inv) => inv['is_cancelled'] == 0)
          .fold(0.0, (sum, inv) => sum + (inv['amount'] as double));

      expect(totalActiveRevenue, 2300.0); // 1500 + 800
    });
  });
}
