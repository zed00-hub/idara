import 'package:flutter_test/flutter_test.dart';
import 'package:ndmha/core/utils/currency_formatter.dart';
import 'package:ndmha/models/cart_item.dart';
import 'package:ndmha/models/product.dart';
import 'package:ndmha/models/customer.dart';
import 'package:ndmha/models/invoice.dart';
import 'package:ndmha/models/expense.dart';
import 'package:ndmha/models/supplier.dart';
import 'package:ndmha/models/cash_register.dart';
import 'package:ndmha/providers/financial_report_provider.dart';
import 'package:ndmha/core/services/storage_service.dart';

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
      expect(change, 10);

      final change2 = CurrencyFormatter.calculateRoundedChange(
        paidAmount: 500,
        totalDue: 483,
      );
      expect(change2, 15);

      final changeUnderpaid = CurrencyFormatter.calculateRoundedChange(
        paidAmount: 100,
        totalDue: 150,
      );
      expect(changeUnderpaid, 0);
    });

    test('format formats currency with DA label and comma separators', () {
      expect(CurrencyFormatter.format(150), '150 دج');
      expect(CurrencyFormatter.format(1250), '1,250 دج');
      expect(CurrencyFormatter.format(150.5), '151 دج');
    });
  });

  group('CartItem & Product Real Business Logic Tests', () {
    final testProduct = Product(
      id: 1,
      barcode: '613000000001',
      name: 'حليب كانديا',
      costPrice: 90.0,
      retailPrice: 110.0,
      wholesalePrice: 100.0,
      quantity: 50,
      category: 'ألبان',
    );

    test('CartItem retail subtotal and profit calculation', () {
      final item = CartItem(
        product: testProduct,
        quantity: 3,
        priceType: PriceType.retail,
      );

      expect(item.unitPrice, 110.0);
      expect(item.subtotal, 330.0);
      expect(item.totalCost, 270.0);
      expect(item.profit, 60.0);
    });

    test('CartItem switchPriceType between retail and wholesale', () {
      final item = CartItem(
        product: testProduct,
        quantity: 10,
        priceType: PriceType.retail,
      );

      expect(item.unitPrice, 110.0);
      expect(item.subtotal, 1100.0);

      item.switchPriceType(PriceType.wholesale);
      expect(item.priceType, PriceType.wholesale);
      expect(item.unitPrice, 100.0);
      expect(item.subtotal, 1000.0);
      expect(item.totalCost, 900.0);
      expect(item.profit, 100.0);
    });

    test('CartItem discounts apply cleanly and prevent negative subtotal', () {
      final item = CartItem(
        product: testProduct,
        quantity: 2,
        priceType: PriceType.retail,
        itemDiscount: 20.0,
      );

      expect(item.subtotal, 200.0);

      item.itemDiscount = 500.0;
      expect(item.subtotal, 0.0);
    });

    test('CartItem serialization toMap and fromMap roundtrip', () {
      final item = CartItem(
        product: testProduct,
        quantity: 5,
        priceType: PriceType.wholesale,
        itemDiscount: 10,
      );

      final map = item.toMap(invoiceId: 42);
      expect(map['invoice_id'], 42);
      expect(map['barcode'], '613000000001');
      expect(map['quantity'], 5.0);
      expect(map['price_type'], 'wholesale');
      expect(map['subtotal'], 490.0);

      final restored = CartItem.fromMap(map);
      expect(restored.product.name, 'حليب كانديا');
      expect(restored.quantity, 5.0);
      expect(restored.priceType, PriceType.wholesale);
      expect(restored.unitPrice, 100.0);
    });
  });

  group('Customer & Debt Financial Model Tests', () {
    test('Customer model serialization and advance credit calculation', () {
      final customer = Customer(
        id: 10,
        name: 'أحمد بن علي',
        phone: '0555123456',
        currentDebt: -300.0,
      );

      expect(customer.currentDebt, -300.0);
      final map = customer.toMap();
      expect(map['current_debt'], -300.0);

      final restored = Customer.fromMap(map);
      expect(restored.id, 10);
      expect(restored.name, 'أحمد بن علي');
      expect(restored.currentDebt, -300.0);
    });

    test('Customer copyWith updates debt and details', () {
      final customer = Customer(id: 1, name: 'سعيد', currentDebt: 500.0);
      final updated = customer.copyWith(currentDebt: 0.0);
      expect(updated.currentDebt, 0.0);
      expect(updated.name, 'سعيد');
    });
  });

  group('Invoice & ZReport Real Calculation Tests', () {
    test('Invoice model serialization and cancellation status', () {
      final invoice = Invoice(
        id: 100,
        invoiceNumber: 'INV-20261108-001',
        subtotal: 1000.0,
        discount: 100.0,
        totalAmount: 900.0,
        paymentType: PaymentType.partial,
        paidAmount: 400.0,
        remainingDebt: 500.0,
        changeGiven: 0.0,
        customerId: 5,
        customerName: 'فاروق',
        isCancelled: false,
      );

      expect(invoice.isCancelled, isFalse);
      expect(invoice.totalAmount, 900.0);

      final map = invoice.toMap();
      expect(map['is_cancelled'], 0);
      expect(map['remaining_debt'], 500.0);

      final fromDb = Invoice.fromMap(map);
      expect(fromDb.invoiceNumber, 'INV-20261108-001');
      expect(fromDb.isCancelled, isFalse);

      final cancelledInvoice = invoice.copyWith(isCancelled: true, cancelledAt: DateTime.now().toIso8601String());
      expect(cancelledInvoice.isCancelled, isTrue);
      expect(cancelledInvoice.toMap()['is_cancelled'], 1);
    });

    test('ZReportSummary financial formula consistency', () {
      final report = ZReportSummary(
        date: '2026-11-08',
        totalInvoices: 15,
        totalSales: 45000.0,
        cashSales: 30000.0,
        creditSales: 15000.0,
        totalDiscounts: 1200.0,
        grossProfit: 12500.0,
        totalExpenses: 2500.0,
        netProfit: 10000.0,
        openingCash: 5000.0,
        expectedDrawerCash: 36000.0,
        debtsCollected: 2000.0,
        profitMarginPercent: 27.78,
      );

      expect(report.netProfit, report.grossProfit - report.totalExpenses);
      expect(report.totalSales, report.cashSales + report.creditSales);
    });

    test('Supplier and CashRegister models serialization', () {
      final supplier = Supplier(id: 1, name: 'سيفيتال', company: 'Cevital', currentDebt: 50000);
      expect(supplier.toMap()['current_debt'], 50000.0);

      final register = CashRegister(id: 1, openingAmount: 5000, cashIn: 2000, cashOut: 1500);
      expect(register.toMap()['opening_amount'], 5000.0);

      final expense = Expense(id: 1, title: 'فاتورة الكهرباء', amount: 3500);
      expect(expense.toMap()['amount'], 3500.0);
    });
  });

  group('Security & PIN Hashing Tests', () {
    test('SHA-256 PIN hashing is deterministic and irreversible', () {
      final hash1 = StorageService.hashPin('1234');
      final hash2 = StorageService.hashPin('1234');
      final hashDiff = StorageService.hashPin('5678');

      expect(hash1, hash2);
      expect(hash1, isNot(equals('1234')));
      expect(hash1, isNot(equals(hashDiff)));
      expect(hash1.length, 64);
    });
  });
}
