import 'package:flutter_test/flutter_test.dart';
import 'package:erp_app/shared/formatters/currency.dart';

void main() {
  group('formatRupee', () {
    test('formats whole number with Indian grouping', () {
      expect(formatRupee(100000), '₹1,00,000');
    });

    test('formats zero', () {
      expect(formatRupee(0), '₹0');
    });

    test('formats small number', () {
      expect(formatRupee(50), '₹50');
    });

    test('formats large number', () {
      expect(formatRupee(1234567), '₹12,34,567');
    });
  });

  group('formatRupeeDecimal', () {
    test('formats with 2 decimal places', () {
      expect(formatRupeeDecimal(1234.5), '₹1,234.50');
    });

    test('formats zero decimal', () {
      expect(formatRupeeDecimal(0), '₹0.00');
    });

    test('preserves decimals', () {
      expect(formatRupeeDecimal(99.99), '₹99.99');
    });
  });
}
