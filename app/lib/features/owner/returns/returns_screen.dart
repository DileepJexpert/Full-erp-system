import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final returnsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/returns');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────

class ReturnsScreen extends ConsumerWidget {
  const ReturnsScreen({super.key});

  static const _statusColors = {
    'PENDING': Color(0xFFEAB308),
    'COMPLETED': Color(0xFF16A34A),
    'REJECTED': Color(0xFFDC2626),
  };

  static const _reasons = [
    'Damaged',
    'Expired',
    'Wrong Item',
    'Quality',
    'Customer Change',
  ];

  static const _refundModes = [
    'Cash',
    'Store Credit',
    'Exchange',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Returns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Return',
            onPressed: () => _showCreateReturnSheet(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(returnsProvider),
        child: returnsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LoadingSkeleton(height: 80),
                ),
              ),
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(returnsProvider),
          ),
          data: (returns) {
            if (returns.isEmpty) {
              return const EmptyState(
                icon: Icons.assignment_return_outlined,
                title: 'No sales returns',
                subtitle: 'Sales returns will appear here.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: returns.length,
              itemBuilder: (context, index) {
                final r = returns[index];
                return _ReturnCard(
                  returnData: r,
                  onTap: () => _showReturnDetail(context, ref, r),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showReturnDetail(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) {
    final items = (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = r['status'] ?? 'PENDING';
    final statusColor = _statusColors[status] ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Return #${r['returnNumber'] ?? r['id'] ?? '-'}',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Original Bill: ${r['originalBillNumber'] ?? '-'}'),
            Text('Reason: ${r['reason'] ?? '-'}'),
            Text('Refund Mode: ${r['refundMode'] ?? '-'}'),
            if (r['date'] != null || r['createdAt'] != null)
              Text(
                'Date: ${formatDate(DateTime.tryParse(r['date'] ?? r['createdAt'] ?? '') ?? DateTime.now())}',
              ),
            const Divider(height: 24),
            Text(
              'Returned Items',
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No items recorded.')
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item['name'] ?? item['itemName'] ?? '-'),
                        ),
                        Text('Qty: ${item['qty'] ?? item['quantity'] ?? 0}'),
                        const SizedBox(width: 12),
                        Text(formatRupee(
                            (item['amount'] ?? item['price'] ?? 0).toDouble())),
                      ],
                    ),
                  )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ${formatRupee((r['amount'] ?? r['totalAmount'] ?? 0).toDouble())}',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateReturnSheet(
      BuildContext context, WidgetRef ref) async {
    final billCtrl = TextEditingController();
    String reason = _reasons.first;
    String refundMode = _refundModes.first;
    final itemNameCtrl = TextEditingController();
    final itemQtyCtrl = TextEditingController();
    final itemAmountCtrl = TextEditingController();
    final List<Map<String, dynamic>> returnItems = [];

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
                  'Create Sales Return',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: billCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Original Bill Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: _reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => reason = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: refundMode,
                  decoration: const InputDecoration(
                    labelText: 'Refund Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: _refundModes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => refundMode = val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Returned Items',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...returnItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['name'] ?? '-'),
                    subtitle: Text(
                        'Qty: ${item['qty']} | ${formatRupee((item['amount'] ?? 0).toDouble())}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: () =>
                          setSheetState(() => returnItems.removeAt(i)),
                    ),
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: itemNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: itemQtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: itemAmountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '\u20B9 ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        if (itemNameCtrl.text.trim().isNotEmpty) {
                          setSheetState(() {
                            returnItems.add({
                              'name': itemNameCtrl.text.trim(),
                              'qty': int.tryParse(itemQtyCtrl.text) ?? 1,
                              'amount':
                                  double.tryParse(itemAmountCtrl.text) ?? 0,
                            });
                            itemNameCtrl.clear();
                            itemQtyCtrl.clear();
                            itemAmountCtrl.clear();
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
                    onPressed: returnItems.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Submit Return'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && billCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/returns', data: {
          'originalBillNumber': billCtrl.text.trim(),
          'reason': reason,
          'refundMode': refundMode,
          'items': returnItems,
          'totalAmount': returnItems.fold<double>(
              0, (sum, item) => sum + (item['amount'] as double)),
        });
        ref.invalidate(returnsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return created successfully'),
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

    billCtrl.dispose();
    itemNameCtrl.dispose();
    itemQtyCtrl.dispose();
    itemAmountCtrl.dispose();
  }
}

// ── Return Card ────────────────────────────────────────────────

class _ReturnCard extends StatelessWidget {
  final Map<String, dynamic> returnData;
  final VoidCallback onTap;

  const _ReturnCard({required this.returnData, required this.onTap});

  static const _statusColors = {
    'PENDING': Color(0xFFEAB308),
    'COMPLETED': Color(0xFF16A34A),
    'REJECTED': Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final returnNum = returnData['returnNumber'] ?? returnData['id'] ?? '-';
    final billNum = returnData['originalBillNumber'] ?? '-';
    final status = returnData['status'] ?? 'PENDING';
    final amount = (returnData['amount'] ?? returnData['totalAmount'] ?? 0).toDouble();
    final date = DateTime.tryParse(
        returnData['date'] ?? returnData['createdAt'] ?? '');
    final statusColor = _statusColors[status] ?? Colors.grey;

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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.assignment_return, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return #$returnNum',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Bill: $billNum',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (date != null)
                          Text(
                            formatDate(date),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupee(amount),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
