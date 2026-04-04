import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'marketplace_provider.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  static const _statusSteps = ['Pending', 'Confirmed', 'Shipped', 'Delivered'];

  int _statusIndex(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(marketplaceOrdersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace Orders'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(marketplaceOrdersProvider),
        child: ordersAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LoadingSkeleton.card(),
              ),
            ),
          ),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(marketplaceOrdersProvider),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No orders yet',
                  subtitle: 'Place orders from the marketplace.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final id = order['id']?.toString() ?? '';
                final status = (order['status'] ?? 'pending').toString();
                final supplierName = order['supplierName'] ??
                    order['supplier']?['name'] ??
                    '-';
                final items = (order['items'] as List?) ?? [];
                final total = (order['total'] ?? 0).toDouble();
                final createdAt = DateTime.tryParse(
                    (order['createdAt'] ?? '').toString());
                final currentStep = _statusIndex(status);
                final isDelivered = status.toLowerCase() == 'delivered';
                final rated = order['rated'] ?? false;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    supplierName,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      formatDate(createdAt),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: const Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              formatRupee(total),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Items list
                        ...items.map((item) {
                          final itemName = item['name'] ?? '-';
                          final qty = item['quantity'] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.circle,
                                    size: 6, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Text('$itemName x $qty',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        // Status timeline
                        _StatusTimeline(
                          steps: _statusSteps,
                          currentStep: currentStep,
                        ),
                        if (isDelivered && !rated) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showRateDialog(context, ref, id),
                              icon: const Icon(Icons.star_outline, size: 18),
                              label: const Text('Rate Supplier'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showRateDialog(BuildContext context, WidgetRef ref, String orderId) {
    int rating = 5;
    final reviewCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rate Supplier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFBBF24),
                      size: 32,
                    ),
                    onPressed: () =>
                        setDialogState(() => rating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reviewCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Review (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await rateSupplier(
                    ref,
                    orderId,
                    rating,
                    reviewCtrl.text.isNotEmpty ? reviewCtrl.text : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final List<String> steps;
  final int currentStep;

  const _StatusTimeline({required this.steps, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // connector line
          final stepIndex = i ~/ 2;
          final done = stepIndex < currentStep;
          return Expanded(
            child: Container(
              height: 3,
              color: done
                  ? const Color(0xFF16A34A)
                  : theme.colorScheme.outlineVariant.withOpacity(0.4),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = stepIndex <= currentStep;
        final isCurrent = stepIndex == currentStep;
        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? const Color(0xFF16A34A)
                    : theme.colorScheme.outlineVariant.withOpacity(0.3),
                border: isCurrent
                    ? Border.all(color: const Color(0xFF16A34A), width: 2)
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: done ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        );
      }),
    );
  }
}
