import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'expenses_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(expensesStartDateProvider.notifier).state = picked.start;
      ref.read(expensesEndDateProvider.notifier).state = picked.end;
    }
  }

  void _clearDateFilter() {
    ref.read(expensesStartDateProvider.notifier).state = null;
    ref.read(expensesEndDateProvider.notifier).state = null;
  }

  Future<void> _showAddExpenseDialog() async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'General';
    final categories = [
      'General',
      'Rent',
      'Utilities',
      'Transport',
      'Maintenance',
      'Supplies',
      'Other',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => category = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '\u20B9 ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && amountCtrl.text.isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/expenses', data: {
          'category': category,
          'description': descCtrl.text.trim(),
          'amount': double.tryParse(amountCtrl.text) ?? 0,
          'date': formatDateApi(DateTime.now()),
        });
        ref.invalidate(expensesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense added successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    descCtrl.dispose();
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final startDate = ref.watch(expensesStartDateProvider);
    final endDate = ref.watch(expensesEndDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(expensesProvider),
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
              const SizedBox(height: 12),
              // Summary total
              expensesAsync.whenOrNull(
                    data: (expenses) {
                      if (expenses.isEmpty) return const SizedBox.shrink();
                      final total = expenses.fold<double>(
                        0,
                        (sum, e) => sum + (e['amount'] ?? 0).toDouble(),
                      );
                      return Card(
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Total Expenses',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall,
                              ),
                              const Spacer(),
                              Text(
                                formatRupee(total),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ) ??
                  const SizedBox.shrink(),
              const SizedBox(height: 12),
              // Expenses list
              expensesAsync.when(
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
                  onRetry: () => ref.invalidate(expensesProvider),
                ),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses found',
                      subtitle: 'Add expenses to track your spending.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = expenses[index];
                      return _ExpenseCard(expense: e);
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

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;

  const _ExpenseCard({required this.expense});

  static const _categoryColors = {
    'rent': Color(0xFF7C3AED),
    'utilities': Color(0xFF2563EB),
    'transport': Color(0xFF0891B2),
    'maintenance': Color(0xFFEA580C),
    'supplies': Color(0xFF16A34A),
    'general': Color(0xFF64748B),
    'other': Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    final date =
        DateTime.tryParse(expense['date'] ?? expense['createdAt'] ?? '');
    final category = expense['category'] ?? 'General';
    final description = expense['description'] ?? '-';
    final amount = (expense['amount'] ?? 0).toDouble();

    final catColor = _categoryColors[category.toString().toLowerCase()] ??
        const Color(0xFF64748B);

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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_outlined,
                color: catColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
            Text(
              formatRupee(amount),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
