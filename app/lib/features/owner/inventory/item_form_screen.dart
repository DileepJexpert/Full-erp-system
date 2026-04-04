import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'inventory_provider.dart';

/// Single item detail provider for edit mode
final _itemDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String?>((ref, id) async {
  if (id == null) return null;
  final api = ref.read(apiClientProvider);
  final response = await api.get('/items/$id');
  final data = response.data;
  if (data is Map<String, dynamic>) {
    return data['data'] ?? data;
  }
  return null;
});

class ItemFormScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const ItemFormScreen({super.key, this.itemId});

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();

  String _unit = 'pcs';
  double _gstRate = 0;
  bool _saving = false;
  bool _initialized = false;

  static const _units = ['pcs', 'kg', 'plate', 'dozen'];
  static const _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  bool get isEditing => widget.itemId != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> item) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = item['name'] ?? '';
    _categoryCtrl.text = item['category'] ?? '';
    _costPriceCtrl.text = (item['costPrice'] ?? '').toString();
    _sellPriceCtrl.text =
        (item['sellPrice'] ?? item['price'] ?? '').toString();
    _unit = item['unit'] ?? 'pcs';
    _gstRate = (item['gstRate'] ?? 0).toDouble();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'unit': _unit,
      'costPrice': double.tryParse(_costPriceCtrl.text) ?? 0,
      'sellPrice': double.tryParse(_sellPriceCtrl.text) ?? 0,
      'gstRate': _gstRate,
    };

    try {
      final api = ref.read(apiClientProvider);
      if (isEditing) {
        await api.put('/items/${widget.itemId}', data: payload);
      } else {
        await api.post('/items', data: payload);
      }
      ref.invalidate(inventoryListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEditing ? 'Item updated successfully' : 'Item created successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add Item'),
      ),
      body: isEditing
          ? ref.watch(_itemDetailProvider(widget.itemId)).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      LoadingSkeleton(height: 56),
                      SizedBox(height: 16),
                      LoadingSkeleton(height: 56),
                      SizedBox(height: 16),
                      LoadingSkeleton(height: 56),
                    ],
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () =>
                      ref.invalidate(_itemDetailProvider(widget.itemId)),
                ),
                data: (item) {
                  if (item != null) _populateFields(item);
                  return _buildForm(context);
                },
              )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Category is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten_outlined),
              ),
              items: _units
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _unit = val);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      border: OutlineInputBorder(),
                      prefixText: '\u20B9 ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _sellPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sell Price',
                      border: OutlineInputBorder(),
                      prefixText: '\u20B9 ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<double>(
              value: _gstRate,
              decoration: const InputDecoration(
                labelText: 'GST Rate',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
              ),
              items: _gstRates
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text('${r.toStringAsFixed(0)}%'),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _gstRate = val);
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving
                  ? 'Saving...'
                  : isEditing
                      ? 'Update Item'
                      : 'Create Item'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
