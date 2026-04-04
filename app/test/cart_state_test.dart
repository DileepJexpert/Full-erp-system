import 'package:flutter_test/flutter_test.dart';
import 'package:erp_app/features/operator/pos/pos_provider.dart';

void main() {
  final testItem = PosItem(
    id: '1',
    name: 'Veg Momo',
    category: 'Food',
    unit: 'plate',
    sellPrice: 100,
    costPrice: 60,
    gstRate: 5,
  );

  final testItem2 = PosItem(
    id: '2',
    name: 'Chicken Momo',
    category: 'Food',
    unit: 'plate',
    sellPrice: 150,
    costPrice: 90,
    gstRate: 5,
  );

  group('CartItem', () {
    test('lineTotal = quantity * sellPrice', () {
      final ci = CartItem(item: testItem, quantity: 3);
      expect(ci.lineTotal, 300);
    });

    test('GST splits correctly at 5%', () {
      final ci = CartItem(item: testItem, quantity: 2);
      // lineTotal = 200, gstRate = 5
      // cgst = 200 * 2.5 / 100 = 5
      // sgst = 200 * 2.5 / 100 = 5
      expect(ci.cgst, 5.0);
      expect(ci.sgst, 5.0);
    });

    test('GST at 0% gives zero tax', () {
      final zeroGstItem = PosItem(
        id: '3', name: 'Water', category: 'Drink',
        unit: 'bottle', sellPrice: 20, costPrice: 10, gstRate: 0,
      );
      final ci = CartItem(item: zeroGstItem, quantity: 1);
      expect(ci.cgst, 0);
      expect(ci.sgst, 0);
    });
  });

  group('CartState', () {
    test('empty cart has zero totals', () {
      const state = CartState();
      expect(state.isEmpty, true);
      expect(state.itemCount, 0);
      expect(state.subtotal, 0);
      expect(state.total, 0);
    });

    test('subtotal sums line totals', () {
      final state = CartState(items: [
        CartItem(item: testItem, quantity: 2),  // 200
        CartItem(item: testItem2, quantity: 1), // 150
      ]);
      expect(state.subtotal, 350);
    });

    test('total = subtotal + cgst + sgst', () {
      final state = CartState(items: [
        CartItem(item: testItem, quantity: 2), // 200 + 5 cgst + 5 sgst
      ]);
      expect(state.subtotal, 200);
      expect(state.cgstTotal, 5.0);
      expect(state.sgstTotal, 5.0);
      expect(state.total, 210.0);
    });

    test('itemCount sums quantities', () {
      final state = CartState(items: [
        CartItem(item: testItem, quantity: 3),
        CartItem(item: testItem2, quantity: 2),
      ]);
      expect(state.itemCount, 5);
    });

    test('default payment mode is cash', () {
      const state = CartState();
      expect(state.paymentMode, PaymentMode.cash);
    });
  });
}
