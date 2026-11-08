# Nadmha Core Accounting & Integrity Rules (قواعد السلامة المحاسبية والتكامل)

1. **Invoice Cancellation Invariants:**
   - Always retain the invoice in SQLite (`is_cancelled = 1`, `cancelled_at = CURRENT_TIMESTAMP`). Never permanently delete invoices from table `invoices`.
   - Reverse items back into inventory: `products.quantity += item.quantity`.
   - In financial calculations (`totalSales`, `grossProfit`, `cashSales`, `creditSales`), ALWAYS filter `WHERE is_cancelled = 0`.
   - Customer debt reversal:
     - Deduct `invoice.remainingDebt` from customer balance: `newDebt = prevDebt - remainingDebt`.
     - Allow negative debt balance (`< 0`) which legitimately represents an advance/credit (تسبيق لصالح الزبون).
     - Provide the merchant with an explicit action to refund advance cash (`refundAdvance`) which brings debt back to 0 and records `cash_out` on open drawer.
   - Drawer cash consistency:
     - If invoice cancelled in current shift: voided sales are excluded from `cashSales`, so DO NOT add `paidAmount` to `cash_out` (to prevent double-deduction).
     - If invoice cancelled from previous shift: record `cash_out = cash_out + paidAmount` because cash is physically being refunded from today's drawer.

2. **Database Integrity & PRAGMA:**
   - Always run `PRAGMA foreign_keys = ON;` in `onConfigure` of SQLite.
   - Maintain `CHECK` constraints on all prices, amounts, quantities, and cash movements (`>= 0`).

3. **Backup & Restore Symmetry:**
   - Every single exported table must have an exact corresponding restore routine.
   - Specifically: `supplier_invoices` must NEVER be omitted from restore.
   - Clear child tables before parent tables to avoid foreign key violation locks during restore.

4. **Code Quality & Safety:**
   - Always guard `BuildContext` across async gaps with `final nav = Navigator.of(ctx);` and `final messenger = ScaffoldMessenger.of(context);` captured before async calls, and `if (!mounted) return;` checks.
   - Always store PIN hashed with SHA-256 (`StorageService.hashPin`).
