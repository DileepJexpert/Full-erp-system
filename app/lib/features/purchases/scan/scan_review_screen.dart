import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../features/owner/suppliers/suppliers_provider.dart';
import '../purchase_provider.dart';

/// Review and edit items extracted from a scanned bill, voice entry, or
/// repeat-last before saving the purchase.
class ScanReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> extractedData;

  const ScanReviewScreen({super.key, required this.extractedData});

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late TextEditingController _supplierController;
  String? _selectedSupplierId;
  late List<_ReviewItem> _items;
  bool _saving = false;
  bool _hasDuplicateWarning = false;

  @override
  void initState() {
    super.initState();
    final data = widget.extractedData;
    _supplierController =
        TextEditingController(text: data['supplierName'] as String? ?? '');
    _selectedSupplierId = data['supplierId'] as String?;
    _hasDuplicateWarning = data['duplicateWarning'] == true;

    final rawItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _items = rawItems.map((item) => _ReviewItem.fromMap(item)).toList();
    if (_items.isEmpty) _items.add(_ReviewItem());
  }

  @override
  void dispose() {
    _supplierController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _grandTotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<void> _save({bool asTemplate = false}) async {
    if (_items.isEmpty) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);

      final purchaseData = <String, dynamic>{
        'supplierId': _selectedSupplierId,
        'supplierName': _supplierController.text.trim(),
        'items': _items
            .map((item) => {
                  'name': item.nameController.text.trim(),
                  'quantity': double.tryParse(item.qtyController.text) ?? 0,
                  'unit': item.unit,
                  'unitPrice': double.tryParse(item.priceController.text) ?? 0,
                  'matchStatus': item.matchStatus,
                })
            .toList(),
        'total': _grandTotal,
        'entryMethod': widget.extractedData['entryMethod'] ?? 'SCAN',
      };

      if (asTemplate) {
        await saveTemplate(api, purchaseData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template saved')),
          );
        }
      } else {
        await savePurchase(api, purchaseData);
        if (mounted) {
          ref.invalidate(todayPurchasesProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase saved & stock updated')),
          );
          context.pop(true);
        }
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

  void _addItem() {
    setState(() => _items.add(_ReviewItem()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Purchase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add item',
            onPressed: _addItem,
          ),
        ],
      ),
      body: Column(
        children: [
          // Duplicate warning
          if (_hasDuplicateWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.warningColor.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Possible duplicate detected. A similar purchase was recorded recently.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supplier selector
                  Text('Supplier',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  suppliersAsync.when(
                    loading: () => TextField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        hintText: 'Loading suppliers...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    error: (_, __) => TextField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        hintText: 'Type supplier name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    data: (suppliers) => Autocomplete<Map<String, dynamic>>(
                      initialValue: TextEditingValue(
                          text: _supplierController.text),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return suppliers;
                        final query = textEditingValue.text.toLowerCase();
                        return suppliers.where((s) =>
                            (s['name'] as String? ?? '')
                                .toLowerCase()
                                .contains(query));
                      },
                      displayStringForOption: (option) =>
                          option['name'] as String? ?? '',
                      onSelected: (supplier) {
                        _supplierController.text =
                            supplier['name'] as String? ?? '';
                        _selectedSupplierId = supplier['id'] as String?;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                        // Sync our controller text
                        if (controller.text != _supplierController.text) {
                          controller.text = _supplierController.text;
                        }
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Search or type supplier name',
                            prefixIcon: Icon(Icons.store),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            _supplierController.text = val;
                          },
                          onSubmitted: (_) => onSubmitted(),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Items header
                  Row(
                    children: [
                      Text('Items',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '${_items.length} item${_items.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Item rows
                  ...List.generate(_items.length, (i) {
                    final item = _items[i];
                    return _buildItemCard(context, item, i);
                  }),
                ],
              ),
            ),
          ),

          // Bottom bar: total + save
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, _ReviewItem item, int index) {
    final hasAlert = item.priceIncreasePercent > 10;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                _matchIcon(item.matchStatus),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.nameController,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Item name',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Qty / Unit / Price row
            Row(
              children: [
                // Quantity
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: item.qtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),

                // Unit
                SizedBox(
                  width: 50,
                  child: Text(
                    item.unit,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),

                const SizedBox(width: 8),

                // Unit price
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: item.priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\u20B9',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const Spacer(),

                // Line total
                Text(
                  '\u20B9${item.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),

            // Price alert banner
            if (hasAlert) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Price increased ${item.priceIncreasePercent.toStringAsFixed(0)}% from last purchase',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _matchIcon(String status) {
    switch (status) {
      case 'matched':
        return const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20);
      case 'uncertain':
        return const Icon(Icons.help, color: AppTheme.warningColor, size: 20);
      default:
        return const Icon(Icons.cancel, color: AppTheme.errorColor, size: 20);
    }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand Total',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '\u20B9${_grandTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save & Update Stock'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _saving ? null : () => _save(asTemplate: true),
              child: const Text('Save as Template'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal model for a row in the review screen
// ---------------------------------------------------------------------------

class _ReviewItem {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final String unit;
  final String matchStatus; // matched | uncertain | unmatched
  final double priceIncreasePercent;
  final double lastPrice;

  _ReviewItem({
    String name = '',
    double quantity = 1,
    double unitPrice = 0,
    this.unit = 'pcs',
    this.matchStatus = 'unmatched',
    this.priceIncreasePercent = 0,
    this.lastPrice = 0,
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(text: quantity.toString()),
        priceController = TextEditingController(text: unitPrice.toString());

  factory _ReviewItem.fromMap(Map<String, dynamic> map) {
    return _ReviewItem(
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'pcs',
      matchStatus: map['matchStatus'] as String? ?? 'unmatched',
      priceIncreasePercent:
          (map['priceIncreasePercent'] as num?)?.toDouble() ?? 0,
      lastPrice: (map['lastPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  double get lineTotal {
    final qty = double.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0;
    return qty * price;
  }

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}
