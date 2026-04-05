import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../features/owner/suppliers/suppliers_provider.dart';
import '../purchase_provider.dart';

/// Repeat the last purchase for a selected supplier with quantity adjustments.
class RepeatPurchaseScreen extends ConsumerStatefulWidget {
  const RepeatPurchaseScreen({super.key});

  @override
  ConsumerState<RepeatPurchaseScreen> createState() =>
      _RepeatPurchaseScreenState();
}

class _RepeatPurchaseScreenState extends ConsumerState<RepeatPurchaseScreen> {
  String? _selectedSupplierId;
  Map<String, dynamic>? _lastPurchase;
  List<_RepeatItem> _items = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  Future<void> _loadLastPurchase(String supplierId) async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _lastPurchase = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/purchases/repeat-last',
          queryParameters: {'supplierId': supplierId});
      final data = response.data as Map<String, dynamic>;
      final purchase = data['data'] as Map<String, dynamic>;

      final rawItems =
          (purchase['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      setState(() {
        _lastPurchase = purchase;
        _items = rawItems.map((item) => _RepeatItem.fromMap(item)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _total => _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<void> _save() async {
    if (_selectedSupplierId == null || _items.isEmpty) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);
      await savePurchase(api, {
        'supplierId': _selectedSupplierId,
        'items': _items
            .where((item) => item.quantity > 0)
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'unit': item.unit,
                  'unitPrice': item.unitPrice,
                })
            .toList(),
        'total': _total,
        'entryMethod': 'REPEAT',
      });

      if (mounted) {
        ref.invalidate(todayPurchasesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase saved successfully')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Repeat Last Purchase')),
      body: Column(
        children: [
          // Supplier dropdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: suppliersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Error loading suppliers: $err'),
              data: (suppliers) => DropdownButtonFormField<String>(
                value: _selectedSupplierId,
                decoration: const InputDecoration(
                  labelText: 'Select Supplier',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                items: suppliers
                    .map((s) => DropdownMenuItem(
                          value: s['id'] as String?,
                          child: Text(s['name'] as String? ?? '-'),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedSupplierId = val);
                  if (val != null) _loadLastPurchase(val);
                },
              ),
            ),
          ),

          // Content
          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.errorColor)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () =>
                          _loadLastPurchase(_selectedSupplierId!),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_items.isEmpty && _selectedSupplierId != null)
            const Expanded(
              child: Center(
                child: Text('No previous purchase found for this supplier'),
              ),
            )
          else if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Select a supplier to load\ntheir last purchase',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildItemRow(context, item, index);
                },
              ),
            ),

          // Bottom bar
          if (_items.isNotEmpty) _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, _RepeatItem item, int index) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Name + unit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '\u20B9${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Quantity stepper
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (item.quantity > 0) {
                      setState(() => item.quantity -= 1);
                    }
                  },
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    item.quantity.toStringAsFixed(
                        item.quantity == item.quantity.roundToDouble() ? 0 : 1),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  onTap: () => setState(() => item.quantity += 1),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Line total
            SizedBox(
              width: 70,
              child: Text(
                '\u20B9${item.lineTotal.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Total',
                    style: TextStyle(color: Colors.grey)),
                Text(
                  '\u20B9${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _RepeatItem {
  final String name;
  final String unit;
  final double unitPrice;
  double quantity;

  _RepeatItem({
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
  });

  factory _RepeatItem.fromMap(Map<String, dynamic> map) {
    return _RepeatItem(
      name: map['name'] as String? ?? '',
      unit: map['unit'] as String? ?? 'pcs',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  double get lineTotal => quantity * unitPrice;
}
