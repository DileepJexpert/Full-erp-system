import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';

final transferHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/transfers');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final locationsForTransferProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/locations');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  String? _fromLocation;
  String? _toLocation;
  final _items = <_TransferItem>[];
  bool _submitting = false;

  void _addItem() {
    setState(() {
      _items.add(_TransferItem());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].nameCtrl.dispose();
      _items[index].qtyCtrl.dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_fromLocation == null || _toLocation == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    if (_fromLocation == _toLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From and To locations must differ')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/transfers/create', data: {
        'fromLocationId': _fromLocation,
        'toLocationId': _toLocation,
        'items': _items
            .map((i) => {
                  'itemId': i.nameCtrl.text.trim(),
                  'quantity': double.tryParse(i.qtyCtrl.text) ?? 0,
                })
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer created')),
        );
        setState(() {
          for (final i in _items) {
            i.nameCtrl.dispose();
            i.qtyCtrl.dispose();
          }
          _items.clear();
        });
        ref.invalidate(transferHistoryProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.nameCtrl.dispose();
      i.qtyCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(locationsForTransferProvider);
    final historyAsync = ref.watch(transferHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transfer'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(transferHistoryProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transfer form
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Transfer',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      locationsAsync.when(
                        loading: () =>
                            const LoadingSkeleton(height: 48),
                        error: (err, _) => Text('Error loading locations: $err'),
                        data: (locations) => Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _fromLocation,
                              decoration: InputDecoration(
                                labelText: 'From Location',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                              items: locations
                                  .map((l) => DropdownMenuItem(
                                        value: l['id']?.toString(),
                                        child:
                                            Text(l['name']?.toString() ?? '-'),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _fromLocation = val),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _toLocation,
                              decoration: InputDecoration(
                                labelText: 'To Location',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                              items: locations
                                  .map((l) => DropdownMenuItem(
                                        value: l['id']?.toString(),
                                        child:
                                            Text(l['name']?.toString() ?? '-'),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _toLocation = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Items',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      ...List.generate(_items.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _items[i].nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Item ID / Name',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _items[i].qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Qty',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Color(0xFFDC2626)),
                                onPressed: () => _removeItem(i),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Submit Transfer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Transfer history
              Text('Transfer History',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => Column(
                  children: List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton(height: 64),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(transferHistoryProvider),
                ),
                data: (transfers) {
                  if (transfers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.swap_horiz_outlined,
                      title: 'No transfers yet',
                      subtitle: 'Create a stock transfer above.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transfers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = transfers[index];
                      final from = t['fromLocation']?['name'] ??
                          t['fromLocationName'] ??
                          '-';
                      final to = t['toLocation']?['name'] ??
                          t['toLocationName'] ??
                          '-';
                      final status =
                          (t['status'] ?? 'pending').toString();
                      final createdAt = DateTime.tryParse(
                          (t['createdAt'] ?? '').toString());
                      final itemCount =
                          (t['items'] as List?)?.length ?? 0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.swap_horiz,
                                  color: Color(0xFF2563EB)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$from  \u2192  $to',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$itemCount item${itemCount == 1 ? '' : 's'} ${createdAt != null ? '- ${formatDate(createdAt)}' : ''}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color:
                                                  const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (status.toLowerCase() == 'completed'
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706))
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: status.toLowerCase() == 'completed'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _TransferItem {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
}
