import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../purchase_provider.dart';

/// Lists saved purchase templates and allows using or deleting them.
class PurchaseTemplatesScreen extends ConsumerWidget {
  const PurchaseTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(purchaseTemplatesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Templates')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(purchaseTemplatesProvider),
        child: templatesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingSkeleton(height: 400),
          ),
          error: (err, _) => Center(
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(purchaseTemplatesProvider),
            ),
          ),
          data: (templates) {
            if (templates.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  EmptyState(
                    icon: Icons.file_copy_outlined,
                    title: 'No templates yet',
                    subtitle:
                        'Save a purchase as template from the review screen',
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return _TemplateCard(
                  template: template,
                  onUse: () => _useTemplate(context, template),
                  onDelete: () =>
                      _confirmDelete(context, ref, template),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _useTemplate(BuildContext context, Map<String, dynamic> template) {
    // Navigate to review screen with template data pre-filled
    final data = Map<String, dynamic>.from(template);
    data['entryMethod'] = 'TEMPLATE';
    context.push('/purchases/scan/review', extra: data);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> template,
  ) async {
    final name = template['name'] as String? ?? 'this template';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final api = ref.read(apiClientProvider);
        await deleteTemplate(api, template['id'] as String);
        ref.invalidate(purchaseTemplatesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template deleted')),
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
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onUse,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = template['name'] as String? ??
        template['supplierName'] as String? ??
        'Untitled';
    final supplierName = template['supplierName'] as String? ?? '';
    final items = (template['items'] as List?)?.length ?? 0;
    final usageCount = (template['usageCount'] as num?)?.toInt() ?? 0;

    return Dismissible(
      key: ValueKey(template['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion in the callback
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onUse,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_copy,
                      color: AppTheme.secondaryColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      if (supplierName.isNotEmpty)
                        Text(supplierName,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$items item${items == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.repeat,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            'Used $usageCount time${usageCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
