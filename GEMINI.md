# Nadmha POS Development Guidelines & Memory

## Inviolable Accounting & System Rules:

1. **Invoice Cancellation (إلغاء الفواتير):**
   - Never physically delete invoices: update with `is_cancelled = 1` and `cancelled_at = CURRENT_TIMESTAMP`.
   - Restore stock quantities: `UPDATE products SET quantity = quantity + qty`.
   - Reverse debt on customer: `newDebt = prevDebt - remainingDebt`.
   - Negative customer balance denotes an advance credit (`تسبيق لصالح الزبون`). Settle it via `CustomerDebtProvider.refundAdvance` which brings balance back towards 0 and registers cash out from the cash register.
   - For cash sales refunded upon cancellation:
     - If cancelled during the same shift: do NOT add to `cash_out` because `FinancialReportProvider` already excludes cancelled invoices from `cashSales` (preventing double deduction).
     - If cancelled from an earlier closed shift: add refund to `cash_out` to reflect physical cash paid from today's drawer.

2. **Financial Reports (التقارير المالية وتقرير Z):**
   - All sales and profit queries MUST filter out cancelled invoices: `WHERE is_cancelled = 0`.
   - Active Cash Sales, Credit Sales, Gross Profit, and Net Profit must strictly reflect active non-cancelled transactions.

3. **Backup & Restore (النسخ الاحتياطي والاستعادة):**
   - Full symmetry: every table in export must be restored in `restoreFromBackup`.
   - Specifically: `supplier_invoices` must ALWAYS be restored.
   - Clear child tables before parent tables to prevent foreign key constraint exceptions.

4. **Database Integrity (قاعدة البيانات):**
   - Enforce `PRAGMA foreign_keys = ON;` in SQLite `onConfigure`.
   - Enforce `CHECK` constraints on prices, quantities, and cash values (`>= 0`).

5. **Flutter & UI Architecture:**
   - Always capture `Navigator.of(ctx)` and `ScaffoldMessenger.of(context)` before `await` and guard with `if (!mounted) return;`.
   - Store security PIN only as a salted SHA-256 hash.
