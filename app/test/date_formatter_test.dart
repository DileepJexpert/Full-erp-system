import 'package:flutter_test/flutter_test.dart';
import 'package:erp_app/shared/formatters/date.dart';

void main() {
  group('formatDate', () {
    test('formats date correctly', () {
      final date = DateTime(2024, 3, 15);
      expect(formatDate(date), '15 Mar 2024');
    });

    test('formats single digit day', () {
      final date = DateTime(2024, 1, 5);
      expect(formatDate(date), '5 Jan 2024');
    });
  });

  group('formatTime', () {
    test('formats time', () {
      final date = DateTime(2024, 1, 1, 14, 30);
      final result = formatTime(date);
      expect(result, contains('2:30'));
    });
  });

  group('formatDateApi', () {
    test('formats as yyyy-MM-dd', () {
      final date = DateTime(2024, 3, 5);
      expect(formatDateApi(date), '2024-03-05');
    });
  });
}
