---
name: ndmha-pos-rules
description: >-
  Essential architectural, accounting, database integrity, and backup runbook rules for the Nadmha POS Flutter application. Use whenever modifying financial calculations, debt tracking, invoice cancellation, backup restoration, or database schemas.
---

# Nadmha POS Engineering & Accounting Skill (قواعد معمارية ومحاسبية لتطبيق نظمها)

This skill serves as the permanent runbook and invariant reference for maintaining, developing, and auditing the Nadmha POS system.

## 1. Accounting Invariants (الثوابت المحاسبية الصارمة)

### A. Invoice Cancellation (إلغاء الفواتير)
- **Soft-Delete Only:** Never `DELETE FROM invoices`. Set `is_cancelled = 1` and record `cancelled_at` to preserve an immutable audit trail.
- **Stock Reversal:** Always restore inventory quantities: `UPDATE products SET quantity = quantity + item.qty WHERE id = item.productId`.
- **Debt Reversal:**
  - When an invoice was issued with debt (`remaining_debt > 0`), it increased customer debt by `remaining_debt`.
  - Upon cancellation, subtract `invoice.remainingDebt` from the customer's balance: `newDebt = prevDebt - invoice.remainingDebt`.
  - If the customer had already paid part/all of that debt, `newDebt` becomes negative (`< 0`). This is **CORRECT**: negative debt in Nadmha denotes an advance / credit balance (تسبيق لصالح الزبون).
- **Cash Register Reconciliations:**
  - If an invoice created in the **current active shift** is cancelled, do NOT add its refund to `cash_out` if `FinancialReportProvider` already excludes cancelled invoices from `cashSales` (doing both would subtract cash twice).
  - If an invoice created in a **previous closed shift** is cancelled and cash is refunded, record `UPDATE cash_register SET cash_out = cash_out + paidAmount` because physical cash is leaving today's drawer.

### B. Customer Balance & Advances (أرصدة الزبائن والتسبيقات)
- `currentDebt > 0`: The customer owes money to the store (دين على الزبون).
- `currentDebt == 0`: Account is settled (خالص).
- `currentDebt < 0`: The store owes money or goods to the customer (تسبيق / رصيد دائن لصالح الزبون).
- **Settlement & Refunds:**
  - When refunding an advance in cash, call `refundAdvance(customerId, amount)`:
    - `newDebt = prevDebt + refundAmount` (moves back towards 0).
    - Logs transaction with `type = 'advance_refund'`.
    - Updates open cash drawer: `UPDATE cash_register SET cash_out = cash_out + refundAmount`.

### C. Financial Reports & Z-Report (التقارير المالية وتقرير Z)
- **Always filter out cancelled invoices:**
  - Sales query: `WHERE is_cancelled = 0 [AND dateRange]`.
  - Profit items query: `JOIN invoices i ON ii.invoice_id = i.id WHERE i.is_cancelled = 0 [AND dateRange]`.
- **Drawer Balance Formula:**
  $$\text{expectedDrawerCash} = \text{openingCash} + \text{cashSales} + \text{debtsCollected} + \text{cashIn} - \text{cashOut}$$
  - `cashSales`: Cash collected from active sales in the period.
  - `debtsCollected`: Cash collected from customer debt payments (`customer_transactions WHERE type = 'debt_payment'`).
  - `cashIn`: Manual deposits.
  - `cashOut`: Expenses, supplier payments, and refunds from past invoices.

---

## 2. Database Integrity & Constraints (سلامة قاعدة البيانات)

### A. Connection Configuration
Always enforce SQLite foreign keys at connection initialization:
```dart
onConfigure: (db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}
```

### B. Schema Constraints (CHECK Constraints)
- Prices and amounts must NEVER be negative:
  - `products`: `cost_price >= 0`, `retail_price >= 0`, `wholesale_price >= 0`.
  - `invoice_items`: `quantity > 0`, `unit_price >= 0`, `subtotal >= 0`.
  - `invoices`: `total_amount >= 0`, `paid_amount >= 0`, `remaining_debt >= 0`.
  - `expenses`: `amount >= 0`.
  - `cash_register`: `opening_amount >= 0`, `cash_in >= 0`, `cash_out >= 0`.

---

## 3. Backup & Restore Runbook (النسخ الاحتياطي والاستعادة)

### All tables MUST be exported and restored symmetrically:
1. `products`
2. `customers`
3. `customer_transactions`
4. `invoices`
5. `invoice_items`
6. `suppliers`
7. `supplier_invoices` ⚠️ *(Never omit! Missing this caused 100% purchase invoice loss in v1.3.6)*
8. `expenses`
9. `cash_register`

### Restoration Transaction Order:
1. Clear tables child-first to respect foreign keys:
   - `invoice_items`, `invoices`, `customer_transactions`, `customers`, `supplier_invoices`, `suppliers`, `expenses`, `cash_register`, `products`.
2. Insert tables parent-first:
   - `products`, `customers`, `invoices`, `invoice_items`, `customer_transactions`, `suppliers`, `supplier_invoices`, `expenses`, `cash_register`.

---

## 4. UI & Flutter Best Practices (معايير الواجهات واستقرار التطبيق)

### Async Context Safety:
Never use `BuildContext` (e.g. `Navigator.of(context)`, `ScaffoldMessenger.of(context)`) after an `await` without:
```dart
final nav = Navigator.of(ctx);
final messenger = ScaffoldMessenger.of(context);
await asyncOperation();
if (!mounted) return;
nav.pop();
messenger.showSnackBar(...);
```

### PIN Security:
Never store PIN in plaintext. Always use salted SHA-256 hash via `StorageService.hashPin(pin)`.
