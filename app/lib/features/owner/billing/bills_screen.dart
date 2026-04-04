import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'billing_provider.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final startDate = ref.read(billsStartDateProvider);
    final endDate = ref.read(billsEndDateProvider);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate, end: endDate)
          : null,
    );
    if (picked != null) {
      ref.read(billsStartDateProvider.notifier).state = picked.start;
      ref.read(billsEndDateProvider.notifier).state = picked.end;
    }
  }

  void _clearDateFilter() {
    ref.read(billsStartDateProvider.notifier).state = null;
    ref.read(billsEndDateProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsProvider);
    final startDate = ref.watch(billsStartDateProvider);
    final endDate = ref.watch(billsEndDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(billsProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range filter
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.date_range,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          startDate != null && endDate != null
                              ? '${formatDate(startDate)} - ${formatDate(endDate)}'
                              : 'All dates',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDateRange,
                        child: const Text('Filter'),
                      ),
                      if (startDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _clearDateFilter,
                          tooltip: 'Clear filter',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bills list
              billsAsync.when(
                loading: () => Column(
                  children: List.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton.card(),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(billsProvider),
                ),
                data: (bills) {
                  if (bills.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No bills found',
                      subtitle: 'Bills will appear here once generated.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return _BillCard(bill: bill);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final billNumber = bill['billNumber'] ?? bill['number'] ?? '-';
    final locationName =
        bill['locationName'] ?? bill['location']?['name'] ?? '-';
    final total = (bill['total'] ?? bill['amount'] ?? 0).toDouble();
    final paymentMode = bill['paymentMode'] ?? bill['paymentMethod'] ?? '-';
    final date = DateTime.tryParse(bill['date'] ?? bill['createdAt'] ?? '');

    Color paymentChipColor;
    switch (paymentMode.toString().toLowerCase()) {
      case 'cash':
        paymentChipColor = const Color(0xFF16A34A);
        break;
      case 'upi':
        paymentChipColor = const Color(0xFF7C3AED);
        break;
      case 'card':
        paymentChipColor = const Color(0xFF2563EB);
        break;
      default:
        paymentChipColor = const Color(0xFF64748B);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$billNumber',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locationName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (date != null)
                    Text(
                      formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupee(total),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paymentChipColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    paymentMode.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: paymentChipColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
