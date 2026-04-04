import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/error_view.dart';
import 'pos_provider.dart';
import 'widgets/item_grid.dart';
import 'widgets/cart_panel.dart';
import 'widgets/payment_sheet.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(posItemsProvider);
    final cart = ref.watch(cartProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: 'Failed to load items: $err',
          onRetry: () => ref.invalidate(posItemsProvider),
        ),
        data: (items) {
          if (isDesktop) {
            // Desktop: side by side
            return Row(
              children: [
                Expanded(flex: 3, child: ItemGrid(items: items)),
                Container(width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(flex: 2, child: CartPanel(cart: cart)),
              ],
            );
          }
          // Mobile: stacked with bottom cart summary
          return Column(
            children: [
              Expanded(child: ItemGrid(items: items)),
              _MobileCartBar(cart: cart),
            ],
          );
        },
      ),
    );
  }
}

class _MobileCartBar extends ConsumerWidget {
  final CartState cart;
  const _MobileCartBar({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.itemCount} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                  Text(
                    formatRupee(cart.total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _showPaymentSheet(context, ref),
              icon: const Icon(Icons.payment),
              label: Text('Pay ${formatRupee(cart.total)}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentSheet(total: cart.total),
    );
  }
}
