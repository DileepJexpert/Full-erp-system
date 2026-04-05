import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../purchases/purchase_provider.dart';

/// Screen for managing item name aliases used by the smart purchase parser.
class AliasesScreen extends ConsumerWidget {
  const AliasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliasesAsync = ref.watch(itemAliasesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Item Aliases')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(itemAliasesProvider),
        child: aliasesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingSkeleton(height: 400),
          ),
          error: (err, _) => Center(
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(itemAliasesProvider),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  EmptyState(
                    icon: Icons.label_outline,
                    title: 'No aliases yet',
                    subtitle:
                        'Aliases help match scanned item names to your inventory',
                  ),
                ],
              );
            }

            // Separate business items (editable) and global aliases (read-only)
            final businessItems = items
                .where((i) => i['isGlobal'] != true)
                .toList();
            final globalAliases = items
                .where((i) => i['isGlobal'] == true)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppTheme.infoColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aliases map scanned names to your inventory items. '
                          'e.g. "Basmati" maps to "Rice - Basmati 1kg".',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppTheme.infoColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Business items
                if (businessItems.isNotEmpty) ...[
                  Text('Your Items',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...businessItems.map((item) => _AliasItemCard(
                        item: item,
                        editable: true,
                        onAddAlias: () =>
                            _showAddAliasDialog(context, ref, item),
                      )),
                ],

                // Global aliases
                if (globalAliases.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Global Aliases',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'System-wide aliases (read-only)',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ...globalAliases.map((item) => _AliasItemCard(
                        item: item,
                        editable: false,
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddAliasDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) async {
    final controller = TextEditingController();
    final itemName = item['name'] as String? ?? '';
    final itemId = item['id'] as String? ?? '';

    final alias = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Alias for "$itemName"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Alias',
            hintText: 'e.g. Basmati, BR-1kg',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (alias != null && alias.isNotEmpty && context.mounted) {
      try {
        final api = ref.read(apiClientProvider);
        await addItemAlias(api, itemId, alias);
        ref.invalidate(itemAliasesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Alias "$alias" added')),
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
    controller.dispose();
  }
}

class _AliasItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool editable;
  final VoidCallback? onAddAlias;

  const _AliasItemCard({
    required this.item,
    required this.editable,
    this.onAddAlias,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final aliases =
        (item['aliases'] as List?)?.cast<String>() ?? <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (editable && onAddAlias != null)
                  TextButton.icon(
                    onPressed: onAddAlias,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            if (aliases.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: aliases.map((alias) {
                  return Chip(
                    label: Text(alias, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No aliases',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
