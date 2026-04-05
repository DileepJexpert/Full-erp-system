import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../shared/widgets/purchase_entry_selector.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../purchases/purchase_provider.dart';

/// Operator stock tab showing today's received deliveries and low-stock alerts.
class StockTabScreen extends ConsumerWidget {
  const StockTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayPurchasesProvider);
    final lowStockAsync = ref.watch(lowStockItemsProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayPurchasesProvider);
        ref.invalidate(lowStockItemsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Big primary button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => PurchaseEntrySelector.show(context),
              icon: const Icon(Icons.inventory_2, size: 24),
              label: const Text(
                'RECEIVED STOCK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Today's deliveries
          Text(
            "Today's Deliveries",
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          todayAsync.when(
            loading: () => const LoadingSkeleton(height: 200),
            error: (err, _) => ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(todayPurchasesProvider),
            ),
            data: (purchases) {
              if (purchases.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No deliveries today',
                  subtitle: 'Tap the button above to record received stock',
                );
              }
              return Column(
                children: purchases.map((p) => _DeliveryCard(purchase: p)).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Low stock alerts
          Text(
            'Low Stock Alerts',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          lowStockAsync.when(
            loading: () => const LoadingSkeleton(height: 100),
            error: (err, _) => ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(lowStockItemsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: AppTheme.successColor, size: 20),
                      SizedBox(width: 10),
                      Text('All items are well stocked'),
                    ],
                  ),
                );
              }
              return Column(
                children: items.map((item) => _LowStockRow(item: item)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> purchase;
  const _DeliveryCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final supplier = purchase['supplierName'] as String? ?? 'Unknown';
    final items = (purchase['items'] as List?)?.length ?? 0;
    final total = (purchase['total'] as num?)?.toDouble() ?? 0;
    final status = purchase['status'] as String? ?? 'PENDING';
    final time = purchase['createdAt'] as String? ?? '';
    final isApproved = status == 'APPROVED';

    // Format time
    String timeLabel = '';
    if (time.isNotEmpty) {
      try {
        final dt = DateTime.parse(time);
        timeLabel =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        timeLabel = time;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '$items item${items == 1 ? '' : 's'}  |  \u20B9${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(timeLabel,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isApproved
                    ? AppTheme.successColor.withOpacity(0.1)
                    : AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isApproved ? Icons.check_circle : Icons.schedule,
                    size: 14,
                    color: isApproved
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isApproved ? 'Approved' : 'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isApproved
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LowStockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final current = (item['centralStock'] as num?)?.toDouble() ?? 0;
    final min = (item['minStockLevel'] as num?)?.toDouble() ?? 0;
    final unit = item['unit'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.errorColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            '${current.toStringAsFixed(0)} / ${min.toStringAsFixed(0)} $unit',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.errorColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
