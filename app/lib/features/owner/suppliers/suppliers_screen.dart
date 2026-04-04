import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'suppliers_provider.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(suppliersProvider),
        child: suppliersAsync.when(
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
            onRetry: () => ref.invalidate(suppliersProvider),
          ),
          data: (suppliers) {
            if (suppliers.isEmpty) {
              return const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No suppliers yet',
                subtitle: 'Add your first supplier to get started.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final s = suppliers[index];
                return _SupplierCard(supplier: s);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddSupplierDialog(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplier Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gstinCtrl,
              decoration: const InputDecoration(
                labelText: 'GSTIN',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
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
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/suppliers', data: {
          'name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'gstin': gstinCtrl.text.trim(),
        });
        ref.invalidate(suppliersProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier added successfully'),
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
    phoneCtrl.dispose();
    gstinCtrl.dispose();
  }
}

class _SupplierCard extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final name = supplier['name'] ?? '-';
    final phone = supplier['phone'] ?? '-';
    final gstin = supplier['gstin'] ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
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
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  Theme.of(context).colorScheme.tertiaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
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
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (gstin.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GSTIN: $gstin',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
