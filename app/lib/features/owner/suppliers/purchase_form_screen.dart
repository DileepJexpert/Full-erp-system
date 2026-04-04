import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'suppliers_screen.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSupplierId;
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  final _items = <_PurchaseItem>[_PurchaseItem()];
  bool _submitting = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_PurchaseItem()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _total => _items.fold(0.0, (sum, item) {
        final qty = double.tryParse(item.qtyController.text) ?? 0;
        final rate = double.tryParse(item.rateController.text) ?? 0;
        return sum + (qty * rate);
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/purchases', data: {
        'supplierId': _selectedSupplierId,
        'invoiceNumber': _invoiceController.text.trim(),
        'notes': _notesController.text.trim(),
        'items': _items
            .map((item) => {
                  'name': item.nameController.text.trim(),
                  'quantity': double.tryParse(item.qtyController.text) ?? 0,
                  'unitPrice': double.tryParse(item.rateController.text) ?? 0,
                })
            .toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase recorded successfully')),
        );
        ref.invalidate(purchasesListProvider);
        context.go('/suppliers');
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
    final suppliersAsync = ref.watch(suppliersListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/suppliers'),
              ),
              const SizedBox(width: 8),
              Text(
                'Record Purchase',
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Supplier',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    suppliersAsync.when(
                      loading: () => const LoadingSkeleton(height: 48),
                      error: (err, _) => ErrorView(
                        message: err.toString(),
                        onRetry: () => ref.invalidate(suppliersListProvider),
                      ),
                      data: (suppliers) =>
                          DropdownButtonFormField<String>(
                        value: _selectedSupplierId,
                        decoration: const InputDecoration(
                          hintText: 'Select supplier',
                          border: OutlineInputBorder(),
                        ),
                        items: suppliers
                            .map((s) => DropdownMenuItem(
                                  value: s['id'] as String?,
                                  child: Text(s['name'] ?? '-'),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedSupplierId = val),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _invoiceController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Items',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Row'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Item name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: item.qtyController,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (v == null || double.tryParse(v) == null)
                                        ? 'Qty'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: item.rateController,
                                decoration: const InputDecoration(
                                  labelText: 'Rate',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixText: '\u20B9',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (v == null || double.tryParse(v) == null)
                                        ? 'Rate'
                                        : null,
                              ),
                            ),
                            if (_items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Color(0xFFDC2626), size: 20),
                                onPressed: () => _removeItem(i),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: \u20B9${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                            : const Icon(Icons.save),
                        label: Text(
                            _submitting ? 'Saving...' : 'Record Purchase'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseItem {
  final nameController = TextEditingController();
  final qtyController = TextEditingController();
  final rateController = TextEditingController();

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    rateController.dispose();
  }
}
