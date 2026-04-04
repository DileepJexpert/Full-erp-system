import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'inventory_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredInventoryProvider);
    final categories = ref.watch(inventoryCategoriesProvider);
    final selectedCategory = ref.watch(inventoryCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(inventoryListProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerLow,
                  isDense: true,
                ),
                onChanged: (val) =>
                    ref.read(inventorySearchProvider.notifier).state = val,
              ),
              const SizedBox(height: 12),
              // Category filter
              if (categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: selectedCategory == null,
                        onSelected: (_) => ref
                            .read(inventoryCategoryFilterProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: 8),
                      ...categories.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c),
                            selected: selectedCategory == c,
                            onSelected: (_) => ref
                                .read(
                                    inventoryCategoryFilterProvider.notifier)
                                .state = selectedCategory == c ? null : c,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Data table
              filteredAsync.when(
                loading: () => Column(
                  children: List.generate(
                    6,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton(height: 52),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(inventoryListProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No items found',
                      subtitle: 'Add items to your inventory to get started.',
                    );
                  }
                  return Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.5),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Unit')),
                          DataColumn(
                              label: Text('Sell Price'), numeric: true),
                          DataColumn(
                              label: Text('GST Rate'), numeric: true),
                        ],
                        rows: items.map((item) {
                          final sellPrice =
                              (item['sellPrice'] ?? item['price'] ?? 0)
                                  .toDouble();
                          final gstRate =
                              (item['gstRate'] ?? 0).toDouble();

                          return DataRow(
                            onSelectChanged: (_) {
                              context.push(
                                  '/inventory/edit/${item['id']}');
                            },
                            cells: [
                              DataCell(Text(
                                item['name'] ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              )),
                              DataCell(Text(item['category'] ?? '-')),
                              DataCell(Text(item['unit'] ?? '-')),
                              DataCell(Text(formatRupee(sellPrice))),
                              DataCell(Text('${gstRate.toStringAsFixed(0)}%')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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
