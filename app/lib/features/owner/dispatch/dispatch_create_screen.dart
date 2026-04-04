import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'dispatch_provider.dart';

class DispatchCreateScreen extends ConsumerStatefulWidget {
  const DispatchCreateScreen({super.key});

  @override
  ConsumerState<DispatchCreateScreen> createState() =>
      _DispatchCreateScreenState();
}

class _DispatchCreateScreenState extends ConsumerState<DispatchCreateScreen> {
  String? _selectedLocationId;
  final _notesController = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  bool _submitting = false;
  bool _prefillLoaded = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _loadPrefill(List<Map<String, dynamic>> prefillItems) {
    if (_prefillLoaded) return;
    _prefillLoaded = true;
    _items.clear();
    for (final item in prefillItems) {
      _items.add({
        'itemId': item['id'] ?? item['itemId'],
        'name': item['name'] ?? '',
        'quantity': 0,
        'unitPrice': (item['unitPrice'] ?? item['price'] ?? 0).toDouble(),
      });
    }
  }

  Future<void> _submit() async {
    final activeItems =
        _items.where((i) => (i['quantity'] as int) > 0).toList();
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with quantity > 0')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await createDispatch(api, {
        'locationId': _selectedLocationId,
        'notes': _notesController.text.trim(),
        'items': activeItems
            .map((i) => {
                  'itemId': i['itemId'],
                  'quantity': i['quantity'],
                })
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispatch created successfully')),
        );
        ref.invalidate(dispatchListProvider);
        context.go('/dispatch');
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
    final locationsAsync = ref.watch(locationsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dispatch'),
              ),
              const SizedBox(width: 8),
              Text(
                'Create Dispatch',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  locationsAsync.when(
                    loading: () => const LoadingSkeleton(height: 48),
                    error: (err, _) => ErrorView(
                      message: err.toString(),
                      onRetry: () => ref.invalidate(locationsListProvider),
                    ),
                    data: (locations) => DropdownButtonFormField<String>(
                      value: _selectedLocationId,
                      decoration: const InputDecoration(
                        hintText: 'Select location',
                        border: OutlineInputBorder(),
                      ),
                      items: locations
                          .map((l) => DropdownMenuItem(
                                value: l['id'] as String?,
                                child: Text(l['name'] ?? '-'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLocationId = value;
                          _prefillLoaded = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Notes',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Optional notes for this dispatch',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Text('Items',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_selectedLocationId == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Select a location to load items',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  else
                    _buildItemsList(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                          _submitting ? 'Submitting...' : 'Create Dispatch'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    final prefillAsync =
        ref.watch(dispatchPrefillProvider(_selectedLocationId!));

    return prefillAsync.when(
      loading: () => Column(
        children: List.generate(
            3,
            (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LoadingSkeleton(height: 48),
                )),
      ),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () =>
            ref.invalidate(dispatchPrefillProvider(_selectedLocationId!)),
      ),
      data: (prefill) {
        final prefillItems =
            (prefill['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loadPrefill(prefillItems);

        if (_items.isEmpty) {
          return const Text(
            'No items available for this location',
            style: TextStyle(color: Color(0xFF94A3B8)),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _items[i]['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Rs ${(_items[i]['unitPrice'] as double).toStringAsFixed(0)}/unit',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue:
                            (_items[i]['quantity'] as int).toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          _items[i]['quantity'] = int.tryParse(val) ?? 0;
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
