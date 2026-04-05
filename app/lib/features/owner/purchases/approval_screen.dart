import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../purchases/purchase_provider.dart';

/// Owner/manager screen to approve or reject pending purchase entries.
class PurchaseApprovalScreen extends ConsumerWidget {
  const PurchaseApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Approvals')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingApprovalsProvider),
        child: pendingAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingSkeleton(height: 400),
          ),
          error: (err, _) => Center(
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(pendingApprovalsProvider),
            ),
          ),
          data: (purchases) {
            if (purchases.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'All caught up',
                    subtitle: 'No purchases pending approval',
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: purchases.length,
              itemBuilder: (context, index) {
                return _ApprovalCard(
                  purchase: purchases[index],
                  onApprove: () => _approve(context, ref, purchases[index]),
                  onReject: () =>
                      _showRejectDialog(context, ref, purchases[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> purchase,
  ) async {
    try {
      final api = ref.read(apiClientProvider);
      await approvePurchase(api, purchase['id'] as String);
      ref.invalidate(pendingApprovalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase approved')),
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

  Future<void> _showRejectDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> purchase,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Purchase'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Enter reason...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final api = ref.read(apiClientProvider);
        await rejectPurchase(
          api,
          purchase['id'] as String,
          reasonController.text.trim(),
        );
        ref.invalidate(pendingApprovalsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase rejected')),
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
    reasonController.dispose();
  }
}

class _ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> purchase;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.purchase,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final location = purchase['locationName'] as String? ?? 'Unknown location';
    final supplier = purchase['supplierName'] as String? ?? 'Unknown supplier';
    final items = (purchase['items'] as List?)?.length ?? 0;
    final total = (purchase['total'] as num?)?.toDouble() ?? 0;
    final enteredBy = purchase['enteredByName'] as String? ?? '';
    final entryMethod = purchase['entryMethod'] as String? ?? 'MANUAL';
    final createdAt = purchase['createdAt'] as String? ?? '';

    // Format date
    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        dateLabel =
            '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        dateLabel = createdAt;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location + entry method badge
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ),
                _EntryMethodBadge(method: entryMethod),
              ],
            ),
            const SizedBox(height: 8),

            // Supplier
            Text(supplier,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),

            // Details
            Row(
              children: [
                Text(
                  '$items item${items == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Text(
                  '\u20B9${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (enteredBy.isNotEmpty || dateLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [if (enteredBy.isNotEmpty) 'by $enteredBy', dateLabel]
                    .where((s) => s.isNotEmpty)
                    .join('  |  '),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ],

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
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

class _EntryMethodBadge extends StatelessWidget {
  final String method;
  const _EntryMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (method) {
      'SCAN' => (Icons.camera_alt, 'Scanned', AppTheme.primaryColor),
      'VOICE' => (Icons.mic, 'Voice', AppTheme.infoColor),
      'REPEAT' => (Icons.replay, 'Repeat', AppTheme.secondaryColor),
      'BARCODE' => (Icons.qr_code, 'Barcode', Colors.teal),
      _ => (Icons.edit, 'Manual', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
