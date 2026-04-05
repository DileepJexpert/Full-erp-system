import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final estimatesTabProvider = StateProvider<int>((ref) => 3); // 0=Draft,1=Sent,2=Accepted,3=All

final estimatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final tab = ref.watch(estimatesTabProvider);
  final statusFilter = ['DRAFT', 'SENT', 'ACCEPTED', null][tab];
  final queryParams = <String, dynamic>{};
  if (statusFilter != null) queryParams['status'] = statusFilter;
  final response = await api.get('/estimates', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────

class EstimatesScreen extends ConsumerWidget {
  const EstimatesScreen({super.key});

  static const _statusColors = {
    'DRAFT': Color(0xFF64748B),
    'SENT': Color(0xFF2563EB),
    'ACCEPTED': Color(0xFF16A34A),
    'REJECTED': Color(0xFFDC2626),
    'CONVERTED': Color(0xFF7C3AED),
  };

  static const _tabLabels = ['Draft', 'Sent', 'Accepted', 'All'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(estimatesTabProvider);
    final estimatesAsync = ref.watch(estimatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Estimate',
            onPressed: () => _showCreateEstimate(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                _tabLabels.length,
                (i) => Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(estimatesTabProvider.notifier).state = i,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: currentTab == i
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        _tabLabels[i],
                        style: TextStyle(
                          fontWeight: currentTab == i
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: currentTab == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(estimatesProvider),
        child: estimatesAsync.when(
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
            onRetry: () => ref.invalidate(estimatesProvider),
          ),
          data: (estimates) {
            if (estimates.isEmpty) {
              return const EmptyState(
                icon: Icons.request_quote_outlined,
                title: 'No estimates found',
                subtitle: 'Create an estimate to send to customers.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: estimates.length,
              itemBuilder: (context, index) {
                final e = estimates[index];
                return _EstimateCard(
                  estimate: e,
                  onTap: () => _showEstimateDetail(context, ref, e),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showEstimateDetail(
      BuildContext context, WidgetRef ref, Map<String, dynamic> estimate) {
    final items =
        (estimate['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = estimate['status'] ?? 'DRAFT';
    final statusColor = _statusColors[status] ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
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
                    'Estimate #${estimate['estimateNumber'] ?? estimate['id'] ?? '-'}',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
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
            Text('Customer: ${estimate['customerName'] ?? estimate['customer'] ?? '-'}'),
            if (estimate['date'] != null || estimate['createdAt'] != null)
              Text(
                'Date: ${formatDate(DateTime.tryParse(estimate['date'] ?? estimate['createdAt'] ?? '') ?? DateTime.now())}',
              ),
            if (estimate['notes'] != null && estimate['notes'].toString().isNotEmpty)
              Text('Notes: ${estimate['notes']}'),
            if (estimate['terms'] != null && estimate['terms'].toString().isNotEmpty)
              Text('Terms: ${estimate['terms']}'),
            const Divider(height: 24),
            Text(
              'Items',
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No items.')
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                              item['description'] ?? item['name'] ?? '-'),
                        ),
                        Expanded(
                          child: Text(
                            'x${item['qty'] ?? item['quantity'] ?? 0}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatRupee(
                                (item['price'] ?? item['amount'] ?? 0)
                                    .toDouble()),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ${formatRupee((estimate['total'] ?? estimate['totalAmount'] ?? 0).toDouble())}',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                if (status == 'DRAFT') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _sendEstimate(context, ref, estimate);
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (status == 'ACCEPTED' || status == 'SENT')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _convertToInvoice(context, ref, estimate);
                      },
                      icon: const Icon(Icons.receipt, size: 18),
                      label: const Text('Convert to Invoice'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEstimate(BuildContext context, WidgetRef ref,
      Map<String, dynamic> estimate) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/estimates/${estimate['id']}/send');
      ref.invalidate(estimatesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estimate sent successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _convertToInvoice(BuildContext context, WidgetRef ref,
      Map<String, dynamic> estimate) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/estimates/${estimate['id']}/convert');
      ref.invalidate(estimatesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Converted to invoice successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showCreateEstimate(
      BuildContext context, WidgetRef ref) async {
    final customerCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final termsCtrl = TextEditingController();
    final List<Map<String, dynamic>> items = [];
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

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
                  'Create Estimate',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Items',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['description'] ?? '-'),
                    subtitle: Text(
                        'Qty: ${item['qty']} x ${formatRupee((item['price'] ?? 0).toDouble())}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: () =>
                          setSheetState(() => items.removeAt(i)),
                    ),
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
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
                      flex: 2,
                      child: TextField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Price',
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
                        if (descCtrl.text.trim().isNotEmpty) {
                          setSheetState(() {
                            items.add({
                              'description': descCtrl.text.trim(),
                              'qty': int.tryParse(qtyCtrl.text) ?? 1,
                              'price':
                                  double.tryParse(priceCtrl.text) ?? 0,
                            });
                            descCtrl.clear();
                            qtyCtrl.clear();
                            priceCtrl.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: termsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Terms & Conditions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: items.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Create Estimate'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && customerCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        final total = items.fold<double>(
          0,
          (sum, i) =>
              sum + ((i['qty'] as int) * (i['price'] as double)),
        );
        await api.post('/estimates', data: {
          'customerName': customerCtrl.text.trim(),
          'items': items,
          'notes': notesCtrl.text.trim(),
          'terms': termsCtrl.text.trim(),
          'total': total,
        });
        ref.invalidate(estimatesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estimate created successfully'),
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

    customerCtrl.dispose();
    notesCtrl.dispose();
    termsCtrl.dispose();
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── Estimate Card ──────────────────────────────────────────────

class _EstimateCard extends StatelessWidget {
  final Map<String, dynamic> estimate;
  final VoidCallback onTap;

  const _EstimateCard({required this.estimate, required this.onTap});

  static const _statusColors = {
    'DRAFT': Color(0xFF64748B),
    'SENT': Color(0xFF2563EB),
    'ACCEPTED': Color(0xFF16A34A),
    'REJECTED': Color(0xFFDC2626),
    'CONVERTED': Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) {
    final estNum = estimate['estimateNumber'] ?? estimate['id'] ?? '-';
    final customer = estimate['customerName'] ?? estimate['customer'] ?? '-';
    final status = estimate['status'] ?? 'DRAFT';
    final total = (estimate['total'] ?? estimate['totalAmount'] ?? 0).toDouble();
    final date = DateTime.tryParse(
        estimate['date'] ?? estimate['createdAt'] ?? '');
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
                child: Icon(Icons.request_quote, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$estNum',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupee(total),
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
