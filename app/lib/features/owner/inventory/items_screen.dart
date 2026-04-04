import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/search_bar.dart';
import 'inventory_provider.dart';

class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredInventoryProvider);
    final categories = ref.watch(inventoryCategoriesProvider);
    final selectedCategory = ref.watch(inventoryCategoryFilterProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inventoryListProvider),
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
                    'Inventory Items',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/inventory/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    hintText: 'Search items...',
                    onChanged: (val) =>
                        ref.read(inventorySearchProvider.notifier).state = val,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      hintText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Categories')),
                      ...categories.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (val) => ref
                        .read(inventoryCategoryFilterProvider.notifier)
                        .state = val,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            filteredAsync.when(
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
                onRetry: () => ref.invalidate(inventoryListProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2,
                    title: 'No items found',
                    subtitle: 'Add items to your inventory',
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Price'), numeric: true),
                      DataColumn(label: Text('Stock'), numeric: true),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: items.map((item) {
                      final price = (item['price'] ?? 0).toDouble();
                      final stock = item['stock'] ?? item['currentStock'] ?? 0;
                      return DataRow(cells: [
                        DataCell(Text(
                          item['name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        )),
                        DataCell(Text(item['category'] ?? '-')),
                        DataCell(Text(item['unit'] ?? '-')),
                        DataCell(Text(formatRupee(price))),
                        DataCell(Text(
                          '$stock',
                          style: TextStyle(
                            color: (stock is int && stock <= 0) ||
                                    (stock is double && stock <= 0)
                                ? const Color(0xFFDC2626)
                                : null,
                            fontWeight: FontWeight.w500,
                          ),
                        )),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () =>
                                context.go('/inventory/edit/${item['id']}'),
                            tooltip: 'Edit',
                          ),
                        ),
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
