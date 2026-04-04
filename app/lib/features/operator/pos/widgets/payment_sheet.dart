import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/formatters/currency.dart';
import '../../../../core/auth/auth_provider.dart';
import '../pos_provider.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  final double total;
  const PaymentSheet({super.key, required this.total});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      // Use user's assigned location or empty string
      final bill = await ref.read(cartProvider.notifier).submitBill('');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill #${bill?['billNumber'] ?? ''} saved! Total: ${formatRupee(widget.total)}'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Confirm Payment', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),

          // Bill summary
          _row('Subtotal', formatRupeeDecimal(cart.subtotal)),
          _row('CGST', formatRupeeDecimal(cart.cgstTotal)),
          _row('SGST', formatRupeeDecimal(cart.sgstTotal)),
          const Divider(height: 24),
          _row('Total', formatRupee(cart.total), bold: true),
          const SizedBox(height: 16),

          // Payment mode display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(
                  cart.paymentMode == PaymentMode.cash ? Icons.money
                      : cart.paymentMode == PaymentMode.upi ? Icons.qr_code
                      : Icons.call_split,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                Text(
                  cart.paymentMode == PaymentMode.cash ? 'Cash Payment'
                      : cart.paymentMode == PaymentMode.upi ? 'UPI Payment'
                      : 'Split Payment',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 20),
                        const SizedBox(width: 8),
                        Text('Save & Print ${formatRupee(cart.total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: bold ? null : const Color(0xFF64748B),
            fontWeight: bold ? FontWeight.w700 : null,
            fontSize: bold ? 18 : null,
          )),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontSize: bold ? 18 : null,
          )),
        ],
      ),
    );
  }
}
