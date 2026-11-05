import 'package:flutter_test/flutter_test.dart';
import 'package:ndmha/core/utils/currency_formatter.dart';

void main() {
  test('CurrencyFormatter rounds change to nearest 5 DZD correctly', () {
    expect(CurrencyFormatter.roundTo5DZD(11), 10);
    expect(CurrencyFormatter.roundTo5DZD(12), 10);
    expect(CurrencyFormatter.roundTo5DZD(13), 15);
    expect(CurrencyFormatter.roundTo5DZD(14), 15);
    expect(CurrencyFormatter.roundTo5DZD(15), 15);
    expect(CurrencyFormatter.roundTo5DZD(18), 20);
    expect(CurrencyFormatter.roundTo5DZD(16), 15);
  });

  test('CurrencyFormatter format with DZD symbol', () {
    expect(CurrencyFormatter.format(1250), '1,250 دج');
    expect(CurrencyFormatter.format(5000), '5,000 دج');
  });
}
