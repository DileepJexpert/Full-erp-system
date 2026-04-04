import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'recon_provider.dart';

class ReconDetailScreen extends ConsumerWidget {
  final String reconId;

  const ReconDetailScreen({super.key, required this.reconId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(reconDetailProvider(reconId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reconciliation Detail'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reconDetailProvider(reconId)),
        child: detailAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const LoadingSkeleton(height: 120),
                const SizedBox(height: 16),
                ...List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LoadingSkeleton(height: 48),
                  ),
                ),
              ],
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(reconDetailProvider(reconId)),
          ),
          data: (recon) {
            final date = DateTime.tryParse(recon['date'] ?? '');
            final locationName =
                recon['location']?['name'] ?? recon['locationName'] ?? '-';
            final totalLoss = (recon['totalLoss'] ?? 0).toDouble();
            final items = (recon['items'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locationName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date != null ? formatDate(date) : '-',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                if (recon['status'] != null) ...[
                                  const SizedBox(height: 8),
                                  Chip(
                                    label: Text(
                                      recon['status'].toString().toUpperCase(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: totalLoss > 0
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Total Loss',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatRupee(totalLoss),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: totalLoss > 0
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Item Breakdown',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No item data available',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ...items.map((item) => _ItemLineCard(item: item)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ItemLineCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemLineCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? item['item']?['name'] ?? '-';
    final dispatched = (item['dispatched'] ?? 0).toInt();
    final sold = (item['sold'] ?? 0).toInt();
    final returned = (item['returned'] ?? 0).toInt();
    final wasted = (item['wasted'] ?? 0).toInt();
    final margin = (item['margin'] ?? 0).toDouble();
    final loss = (item['chargeableLoss'] ?? item['loss'] ?? 0).toDouble();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _QtyChip(label: 'Dispatched', value: '$dispatched'),
                const SizedBox(width: 8),
                _QtyChip(label: 'Sold', value: '$sold'),
                const SizedBox(width: 8),
                _QtyChip(label: 'Returned', value: '$returned'),
                const SizedBox(width: 8),
                _QtyChip(
                  label: 'Wasted',
                  value: '$wasted',
                  color: wasted > 0 ? const Color(0xFFDC2626) : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Margin: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatRupeeDecimal(margin),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: margin >= 0
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Chargeable Loss: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatRupeeDecimal(loss),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: loss > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _QtyChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
