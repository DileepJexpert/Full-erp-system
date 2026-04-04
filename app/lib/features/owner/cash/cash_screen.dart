import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'cash_provider.dart';

class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen> {
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(cashStartDateProvider.notifier).state = picked.start;
      ref.read(cashEndDateProvider.notifier).state = picked.end;
    }
  }

  void _clearDateFilter() {
    ref.read(cashStartDateProvider.notifier).state = null;
    ref.read(cashEndDateProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final cashAsync = ref.watch(cashCollectionsProvider);
    final startDate = ref.watch(cashStartDateProvider);
    final endDate = ref.watch(cashEndDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Collections'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cashCollectionsProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date filter
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
              // Cash collections list
              cashAsync.when(
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
                  onRetry: () => ref.invalidate(cashCollectionsProvider),
                ),
                data: (collections) {
                  if (collections.isEmpty) {
                    return const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No cash collections found',
                      subtitle:
                          'Cash collection records will appear here.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: collections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = collections[index];
                      return _CashCollectionCard(collection: c);
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

class _CashCollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;

  const _CashCollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(
        collection['date'] ?? collection['createdAt'] ?? '');
    final location = collection['locationName'] ??
        collection['location']?['name'] ??
        '-';
    final expected = (collection['expected'] ??
            collection['expectedAmount'] ??
            0)
        .toDouble();
    final actual = (collection['actual'] ??
            collection['actualAmount'] ??
            collection['collected'] ??
            0)
        .toDouble();
    final shortfall = expected - actual;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: shortfall > 0
              ? const Color(0xFFFCA5A5)
              : Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: shortfall > 0
                        ? const Color(0xFFFEE2E2)
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: shortfall > 0
                        ? const Color(0xFFDC2626)
                        : Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (date != null)
                        Text(
                          formatDate(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (shortfall > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'SHORT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _AmountItem(
                  label: 'Expected',
                  amount: expected,
                ),
                const SizedBox(width: 16),
                _AmountItem(
                  label: 'Actual',
                  amount: actual,
                ),
                const SizedBox(width: 16),
                _AmountItem(
                  label: 'Shortfall',
                  amount: shortfall,
                  color: shortfall > 0 ? const Color(0xFFDC2626) : null,
                  bold: shortfall > 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final bool bold;

  const _AmountItem({
    required this.label,
    required this.amount,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupee(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
