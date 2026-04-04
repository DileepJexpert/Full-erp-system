import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

final cashCollectionListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/cash');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final _locationsForCashProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/locations');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

class CashCollectionScreen extends ConsumerStatefulWidget {
  const CashCollectionScreen({super.key});

  @override
  ConsumerState<CashCollectionScreen> createState() =>
      _CashCollectionScreenState();
}

class _CashCollectionScreenState extends ConsumerState<CashCollectionScreen> {
  bool _showForm = false;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedLocationId;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/cash', data: {
        'locationId': _selectedLocationId,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash collection recorded')),
        );
        ref.invalidate(cashCollectionListProvider);
        setState(() {
          _showForm = false;
          _amountController.clear();
          _notesController.clear();
          _selectedLocationId = null;
        });
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
  Widget build(BuildContext context) {
    final cashAsync = ref.watch(cashCollectionListProvider);
    final locationsAsync = ref.watch(_locationsForCashProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cashCollectionListProvider),
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
                    'Cash Collection',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => setState(() => _showForm = !_showForm),
                  icon: Icon(_showForm ? Icons.close : Icons.add, size: 18),
                  label: Text(_showForm ? 'Cancel' : 'Record Collection'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Inline form
            if (_showForm)
              Card(
                color: const Color(0xFFF0FDF4),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Collection',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        locationsAsync.when(
                          loading: () => const LoadingSkeleton(height: 48),
                          error: (err, _) => Text('Error loading locations: $err'),
                          data: (locations) =>
                              DropdownButtonFormField<String>(
                            value: _selectedLocationId,
                            decoration: const InputDecoration(
                              labelText: 'Location *',
                              border: OutlineInputBorder(),
                            ),
                            items: locations
                                .map((l) => DropdownMenuItem(
                                      value: l['id'] as String?,
                                      child: Text(l['name'] ?? '-'),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedLocationId = val),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _amountController,
                                decoration: const InputDecoration(
                                  labelText: 'Amount Collected *',
                                  border: OutlineInputBorder(),
                                  prefixText: '\u20B9 ',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (v == null || double.tryParse(v) == null)
                                        ? 'Valid amount required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                              _submitting ? 'Saving...' : 'Save Collection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showForm) const SizedBox(height: 20),
            // Cash collection list
            cashAsync.when(
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
                onRetry: () => ref.invalidate(cashCollectionListProvider),
              ),
              data: (collections) {
                if (collections.isEmpty) {
                  return const EmptyState(
                    icon: Icons.attach_money,
                    title: 'No cash collections yet',
                    subtitle: 'Record cash collected from locations',
                  );
                }

                final totalCollected = collections.fold<double>(
                    0.0, (sum, c) => sum + (c['amount'] ?? 0).toDouble());

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: const Color(0xFFF0FDF4),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_money,
                                color: Color(0xFF16A34A)),
                            const SizedBox(width: 12),
                            Text(
                              '${collections.length} collections',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            Text(
                              'Total: ${formatRupee(totalCollected)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Location')),
                          DataColumn(label: Text('Collected By')),
                          DataColumn(
                              label: Text('Amount'), numeric: true),
                          DataColumn(label: Text('Notes')),
                        ],
                        rows: collections.map((c) {
                          final date = DateTime.tryParse(
                              c['date'] ?? c['createdAt'] ?? '');
                          final amount = (c['amount'] ?? 0).toDouble();

                          return DataRow(cells: [
                            DataCell(Text(
                                date != null ? formatDateTime(date) : '-')),
                            DataCell(Text(c['location']?['name'] ??
                                c['locationName'] ??
                                '-')),
                            DataCell(Text(c['collectedBy']?['name'] ??
                                c['collectedByName'] ??
                                '-')),
                            DataCell(Text(
                              formatRupee(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A),
                              ),
                            )),
                            DataCell(Text(c['notes'] ?? '-')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
