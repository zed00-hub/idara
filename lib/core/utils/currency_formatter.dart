import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'en_US');

  /// Formats any double/int value to a clean Algerian Dinar string (e.g. "1,250 دج")
  static String format(num amount, {String currency = 'دج'}) {
    final rounded = amount.round();
    return '${_formatter.format(rounded)} $currency';
  }

  /// Format without currency suffix
  static String formatNumber(num amount) {
    return _formatter.format(amount.round());
  }

  /// Rounds change / remaining amounts to nearest 5 DZD (Algiers standard practice)
  /// e.g. 13 -> 15, 12 -> 10, 11 -> 10, 14 -> 15, -13 -> -15
  static int roundTo5DZD(num amount) {
    if (amount < 0) {
      return -roundTo5DZD(-amount);
    }
    final int val = amount.round();
    final int remainder = val % 5;
    if (remainder == 0) return val;
    if (remainder >= 3) {
      return val + (5 - remainder);
    } else {
      return val - remainder;
    }
  }

  /// Calculates the rounded change for the cashier
  static int calculateRoundedChange({
    required num totalDue,
    required num paidAmount,
  }) {
    if (paidAmount <= totalDue) return 0;
    final exactChange = paidAmount - totalDue;
    return roundTo5DZD(exactChange);
  }
}
