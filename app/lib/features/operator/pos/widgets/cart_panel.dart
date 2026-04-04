import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/formatters/currency.dart';
import '../pos_provider.dart';
import 'payment_sheet.dart';

class CartPanel extends ConsumerWidget {
  final CartState cart;
  const CartPanel({super.key, required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart (${cart.itemCount})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (!cart.isEmpty)
                  TextButton(
                    onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                    child: const Text('Clear', style: TextStyle(color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cart items
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 8),
                        Text('No items in cart', style: TextStyle(color: Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final cartItem = cart.items[index];
                      return _CartItemRow(cartItem: cartItem);
                    },
                  ),
          ),

          // Totals
          if (!cart.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _totalRow(context, 'Subtotal', formatRupeeDecimal(cart.subtotal)),
                  const SizedBox(height: 4),
                  _totalRow(context, 'CGST', formatRupeeDecimal(cart.cgstTotal), light: true),
                  const SizedBox(height: 4),
                  _totalRow(context, 'SGST', formatRupeeDecimal(cart.sgstTotal), light: true),
                  const Divider(height: 16),
                  _totalRow(context, 'TOTAL', formatRupee(cart.total), bold: true, large: true),
                  const SizedBox(height: 16),
                  // Payment buttons
                  Row(
                    children: [
                      _paymentModeButton(context, ref, 'Cash', PaymentMode.cash, Icons.money),
                      const SizedBox(width: 8),
                      _paymentModeButton(context, ref, 'UPI', PaymentMode.upi, Icons.qr_code),
                      const SizedBox(width: 8),
                      _paymentModeButton(context, ref, 'Split', PaymentMode.mixed, Icons.call_split),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: cart.isSubmitting ? null : () => _showPayment(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      child: cart.isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Pay ${formatRupee(cart.total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value, {bool bold = false, bool light = false, bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: light ? const Color(0xFF94A3B8) : null,
          fontWeight: bold ? FontWeight.w700 : null,
          fontSize: large ? 18 : null,
        )),
        Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : null,
          fontSize: large ? 18 : null,
        )),
      ],
    );
  }

  Widget _paymentModeButton(BuildContext context, WidgetRef ref, String label, PaymentMode mode, IconData icon) {
    final cart = ref.watch(cartProvider);
    final isSelected = cart.paymentMode == mode;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => ref.read(cartProvider.notifier).setPaymentMode(mode),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFEFF6FF) : null,
          side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  void _showPayment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentSheet(total: cart.total),
    );
  }
}

class _CartItemRow extends ConsumerWidget {
  final CartItem cartItem;
  const _CartItemRow({required this.cartItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${formatRupee(cartItem.item.sellPrice)} × ${cartItem.quantity}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          // Quantity controls
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyButton(Icons.remove, () {
                  ref.read(cartProvider.notifier).updateQuantity(cartItem.item.id, cartItem.quantity - 1);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('${cartItem.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                _qtyButton(Icons.add, () {
                  ref.read(cartProvider.notifier).updateQuantity(cartItem.item.id, cartItem.quantity + 1);
                }),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              formatRupee(cartItem.lineTotal),
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
      ),
    );
  }
}
