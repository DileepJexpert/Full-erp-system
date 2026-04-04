import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'dispatch_provider.dart';

class DispatchListScreen extends ConsumerWidget {
  const DispatchListScreen({super.key});

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFEAB308);
      case 'DISPATCHED':
        return const Color(0xFF2563EB);
      case 'DELIVERED':
        return const Color(0xFF16A34A);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatchAsync = ref.watch(dispatchListProvider);
    final dateFilter = ref.watch(dispatchDateFilterProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dispatchListProvider),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dispatches',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    ref.read(dispatchDateFilterProvider.notifier).state = picked;
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    dateFilter != null ? formatDate(dateFilter) : 'All Dates',
                  ),
                ),
                if (dateFilter != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () =>
                        ref.read(dispatchDateFilterProvider.notifier).state =
                            null,
                    tooltip: 'Clear filter',
                  ),
                ],
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/dispatch/create'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Dispatch'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            dispatchAsync.when(
              loading: () => Column(
                children: List.generate(
                    5,
                    (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LoadingSkeleton(height: 72),
                        )),
              ),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(dispatchListProvider),
              ),
              data: (dispatches) {
                if (dispatches.isEmpty) {
                  return const EmptyState(
                    icon: Icons.send,
                    title: 'No dispatches found',
                    subtitle: 'Create a new dispatch to get started',
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('Items')),
                      DataColumn(label: Text('Total Value')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Notes')),
                    ],
                    rows: dispatches.map((d) {
                      final date = DateTime.tryParse(d['date'] ?? '');
                      final items = d['items'] as List? ?? [];
                      final totalValue = (d['totalValue'] ?? 0).toDouble();
                      final status = d['status'] ?? 'PENDING';
                      return DataRow(cells: [
                        DataCell(Text(
                            date != null ? formatDate(date) : '-')),
                        DataCell(Text(
                            d['location']?['name'] ?? d['locationName'] ?? '-')),
                        DataCell(Text('${items.length} items')),
                        DataCell(Text(formatRupee(totalValue))),
                        DataCell(
                          Chip(
                            label: Text(
                              status,
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor:
                                _statusColor(status).withOpacity(0.1),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        DataCell(Text(
                          d['notes'] ?? '-',
                          overflow: TextOverflow.ellipsis,
                        )),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
