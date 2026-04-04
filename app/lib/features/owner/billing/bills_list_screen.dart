import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'billing_provider.dart';

class BillsListScreen extends ConsumerWidget {
  const BillsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsListProvider);
    final dateFilter = ref.watch(billingDateFilterProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(billsListProvider),
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
                    'Bills',
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
                    ref.read(billingDateFilterProvider.notifier).state = picked;
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
                        ref.read(billingDateFilterProvider.notifier).state =
                            null,
                    tooltip: 'Clear filter',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            billsAsync.when(
              loading: () => Column(
                children: List.generate(
                    5,
                    (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LoadingSkeleton(height: 56),
                        )),
              ),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(billsListProvider),
              ),
              data: (bills) {
                if (bills.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long,
                    title: 'No bills found',
                    subtitle: 'Bills will appear here as sales are recorded',
                  );
                }

                final totalAmount = bills.fold<double>(
                    0.0, (sum, b) => sum + (b['totalAmount'] ?? b['total'] ?? 0).toDouble());

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Totals summary
                    Card(
                      color: const Color(0xFFF0F9FF),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: Color(0xFF2563EB)),
                            const SizedBox(width: 12),
                            Text(
                              '${bills.length} bills',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                            ),
                            const Spacer(),
                            Text(
                              'Total: ${formatRupee(totalAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('Bill #')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Location')),
                            DataColumn(label: Text('Items')),
                            DataColumn(
                                label: Text('Amount'), numeric: true),
                            DataColumn(label: Text('Payment')),
                          ],
                          rows: bills.map((b) {
                            final date =
                                DateTime.tryParse(b['createdAt'] ?? b['date'] ?? '');
                            final amount =
                                (b['totalAmount'] ?? b['total'] ?? 0)
                                    .toDouble();
                            final items = b['items'] as List? ?? [];

                            return DataRow(cells: [
                              DataCell(Text(
                                b['billNumber'] ?? b['id']?.toString().substring(0, 8) ?? '-',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w500),
                              )),
                              DataCell(Text(
                                  date != null ? formatDateTime(date) : '-')),
                              DataCell(Text(b['location']?['name'] ??
                                  b['locationName'] ??
                                  '-')),
                              DataCell(Text('${items.length}')),
                              DataCell(Text(
                                formatRupee(amount),
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              )),
                              DataCell(Chip(
                                label: Text(
                                  b['paymentMode'] ?? b['paymentMethod'] ?? 'CASH',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                                backgroundColor: const Color(0xFFF1F5F9),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
