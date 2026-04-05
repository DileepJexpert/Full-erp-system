import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final recipesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/recipes');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final recipeDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/recipes/$id');
  return response.data as Map<String, dynamic>;
});

// ── Screen ─────────────────────────────────────────────────────

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes / BOM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Recipe',
            onPressed: () => _showRecipeForm(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recipesProvider),
        child: recipesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LoadingSkeleton(height: 72),
                ),
              ),
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(recipesProvider),
          ),
          data: (recipes) {
            if (recipes.isEmpty) {
              return const EmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: 'No recipes yet',
                subtitle: 'Create recipes to manage your bill of materials.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final r = recipes[index];
                return _RecipeCard(
                  recipe: r,
                  onTap: () => _showRecipeDetail(context, ref, r),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showRecipeDetail(
      BuildContext context, WidgetRef ref, Map<String, dynamic> recipe) {
    final ingredients =
        (recipe['ingredients'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final outputQty = (recipe['outputQty'] ?? recipe['outputQuantity'] ?? 1).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final consumptionCtrl = TextEditingController();
          double? dispatchQty;

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (ctx, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  recipe['name'] ?? recipe['outputItem'] ?? '-',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Output Qty: $outputQty ${recipe['outputUnit'] ?? 'pcs'}'),
                const Divider(height: 24),
                Text(
                  'Ingredients',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (ingredients.isEmpty)
                  const Text('No ingredients added.')
                else
                  ...ingredients.map((ing) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(ing['name'] ?? ing['itemName'] ?? '-'),
                            ),
                            Text(
                              '${ing['qty'] ?? ing['quantity'] ?? 0} ${ing['unit'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (ing['wastage'] != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(+${ing['wastage']}% wastage)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
                const Divider(height: 24),
                // Consumption for 100 units
                Text(
                  'Consumption for 100 units',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...ingredients.map((ing) {
                  final qty = (ing['qty'] ?? ing['quantity'] ?? 0).toDouble();
                  final wastage = (ing['wastage'] ?? 0).toDouble();
                  final per100 = (qty / outputQty) * 100 * (1 + wastage / 100);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(ing['name'] ?? ing['itemName'] ?? '-'),
                        ),
                        Text(
                          '${per100.toStringAsFixed(2)} ${ing['unit'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                // Calculate Consumption
                Text(
                  'Calculate Consumption',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: consumptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dispatch Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setSheetState(() {
                            dispatchQty = double.tryParse(val);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (dispatchQty != null && dispatchQty! > 0) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Theme.of(ctx)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ingredients.map((ing) {
                          final qty =
                              (ing['qty'] ?? ing['quantity'] ?? 0).toDouble();
                          final wastage =
                              (ing['wastage'] ?? 0).toDouble();
                          final needed = (qty / outputQty) *
                              dispatchQty! *
                              (1 + wastage / 100);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      ing['name'] ?? ing['itemName'] ?? '-'),
                                ),
                                Text(
                                  '${needed.toStringAsFixed(2)} ${ing['unit'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRecipeForm(BuildContext context, WidgetRef ref,
      [Map<String, dynamic>? existing]) async {
    final nameCtrl =
        TextEditingController(text: existing?['name'] ?? existing?['outputItem'] ?? '');
    final outputQtyCtrl = TextEditingController(
        text: (existing?['outputQty'] ?? existing?['outputQuantity'] ?? '')
            .toString());
    final outputUnitCtrl =
        TextEditingController(text: existing?['outputUnit'] ?? 'pcs');
    final List<Map<String, dynamic>> ingredients = List.from(
        (existing?['ingredients'] as List?)?.cast<Map<String, dynamic>>() ??
            []);

    final ingNameCtrl = TextEditingController();
    final ingQtyCtrl = TextEditingController();
    final ingUnitCtrl = TextEditingController(text: 'kg');
    final ingWastageCtrl = TextEditingController(text: '0');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  existing != null ? 'Edit Recipe' : 'Create Recipe',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Output Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: outputQtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Output Qty',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: outputUnitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingredients',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...ingredients.asMap().entries.map((entry) {
                  final i = entry.key;
                  final ing = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(ing['name'] ?? '-'),
                    subtitle: Text(
                        '${ing['qty']} ${ing['unit']} (wastage: ${ing['wastage']}%)'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: () =>
                          setSheetState(() => ingredients.removeAt(i)),
                    ),
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: ingNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Item',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: ingQtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: ingUnitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: ingWastageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'W%',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        if (ingNameCtrl.text.trim().isNotEmpty) {
                          setSheetState(() {
                            ingredients.add({
                              'name': ingNameCtrl.text.trim(),
                              'qty': double.tryParse(ingQtyCtrl.text) ?? 0,
                              'unit': ingUnitCtrl.text.trim(),
                              'wastage':
                                  double.tryParse(ingWastageCtrl.text) ?? 0,
                            });
                            ingNameCtrl.clear();
                            ingQtyCtrl.clear();
                            ingUnitCtrl.text = 'kg';
                            ingWastageCtrl.text = '0';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: nameCtrl.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: Text(existing != null ? 'Update' : 'Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        final body = {
          'name': nameCtrl.text.trim(),
          'outputQty': double.tryParse(outputQtyCtrl.text) ?? 1,
          'outputUnit': outputUnitCtrl.text.trim(),
          'ingredients': ingredients,
        };
        if (existing != null && existing['id'] != null) {
          await api.put('/recipes/${existing['id']}', data: body);
        } else {
          await api.post('/recipes', data: body);
        }
        ref.invalidate(recipesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(existing != null
                  ? 'Recipe updated successfully'
                  : 'Recipe created successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    nameCtrl.dispose();
    outputQtyCtrl.dispose();
    outputUnitCtrl.dispose();
    ingNameCtrl.dispose();
    ingQtyCtrl.dispose();
    ingUnitCtrl.dispose();
    ingWastageCtrl.dispose();
  }
}

// ── Recipe Card ────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onTap;

  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = recipe['name'] ?? recipe['outputItem'] ?? '-';
    final outputQty = recipe['outputQty'] ?? recipe['outputQuantity'] ?? 0;
    final outputUnit = recipe['outputUnit'] ?? 'pcs';
    final ingredients =
        (recipe['ingredients'] as List?)?.length ?? recipe['ingredientCount'] ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu,
                    color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                    const SizedBox(height: 4),
                    Text(
                      'Output: $outputQty $outputUnit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$ingredients ingredients',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
