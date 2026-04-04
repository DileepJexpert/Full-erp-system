import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

final expensesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/expenses');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Expense'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Rent, Utilities, Transport',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(),
                  prefixText: '\u20B9 ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text);
      if (categoryController.text.trim().isEmpty || amount == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category and valid amount required')),
          );
        }
        categoryController.dispose();
        amountController.dispose();
        descriptionController.dispose();
        return;
      }

      try {
        final api = ref.read(apiClientProvider);
        await api.post('/expenses', data: {
          'category': categoryController.text.trim(),
          'amount': amount,
          'description': descriptionController.text.trim(),
        });
        ref.invalidate(expensesListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense recorded')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }

    categoryController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(expensesListProvider),
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
                    'Expenses',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Expense'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            expensesAsync.when(
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
                onRetry: () => ref.invalidate(expensesListProvider),
              ),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt,
                    title: 'No expenses recorded',
                    subtitle: 'Track your business expenses here',
                  );
                }

                final totalExpenses = expenses.fold<double>(
                    0.0, (sum, e) => sum + (e['amount'] ?? 0).toDouble());

                // Group by category
                final categoryTotals = <String, double>{};
                for (final e in expenses) {
                  final cat = e['category']?.toString() ?? 'Other';
                  categoryTotals[cat] =
                      (categoryTotals[cat] ?? 0) + (e['amount'] ?? 0).toDouble();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary
                    Card(
                      color: const Color(0xFFFFF7ED),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt,
                                color: Color(0xFFEA580C)),
                            const SizedBox(width: 12),
                            Text(
                              '${expenses.length} expenses',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            Text(
                              'Total: ${formatRupee(totalExpenses)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Category breakdown chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoryTotals.entries.map((e) {
                        return Chip(
                          label: Text(
                            '${e.key}: ${formatRupee(e.value)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          side: BorderSide.none,
                          backgroundColor: const Color(0xFFF1F5F9),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Expenses list
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Amount'), numeric: true),
                        ],
                        rows: expenses.map((e) {
                          final date = DateTime.tryParse(
                              e['date'] ?? e['createdAt'] ?? '');
                          final amount = (e['amount'] ?? 0).toDouble();

                          return DataRow(cells: [
                            DataCell(Text(
                                date != null ? formatDate(date) : '-')),
                            DataCell(Chip(
                              label: Text(
                                e['category'] ?? '-',
                                style: const TextStyle(fontSize: 11),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                              backgroundColor: const Color(0xFFF1F5F9),
                            )),
                            DataCell(Text(e['description'] ?? '-')),
                            DataCell(Text(
                              formatRupee(amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            )),
                          ]);
                        }).toList(),
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
