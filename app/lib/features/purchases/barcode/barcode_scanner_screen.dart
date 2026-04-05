import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../purchase_provider.dart';

/// Manual barcode entry screen that accumulates scanned items into a purchase.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final _barcodeController = TextEditingController();
  final _focusNode = FocusNode();
  final _scannedItems = <_BarcodeItem>[];
  bool _looking = false;
  bool _saving = false;
  String? _lookupError;

  @override
  void dispose() {
    _barcodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double get _total =>
      _scannedItems.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<void> _lookup() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    setState(() {
      _looking = true;
      _lookupError = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/purchases/barcode-lookup',
          queryParameters: {'barcode': barcode});
      final data = response.data as Map<String, dynamic>;
      final item = data['data'] as Map<String, dynamic>;

      // Check if already in list
      final existingIndex = _scannedItems.indexWhere(
          (i) => i.barcode == barcode);

      setState(() {
        if (existingIndex >= 0) {
          _scannedItems[existingIndex].quantity += 1;
        } else {
          _scannedItems.add(_BarcodeItem(
            barcode: barcode,
            name: item['name'] as String? ?? barcode,
            unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
            unit: item['unit'] as String? ?? 'pcs',
            quantity: 1,
          ));
        }
        _barcodeController.clear();
      });
      _focusNode.requestFocus();
    } catch (e) {
      setState(() => _lookupError = 'Item not found for barcode: $barcode');
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _done() async {
    if (_scannedItems.isEmpty) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);
      await savePurchase(api, {
        'items': _scannedItems
            .map((item) => {
                  'name': item.name,
                  'barcode': item.barcode,
                  'quantity': item.quantity,
                  'unit': item.unit,
                  'unitPrice': item.unitPrice,
                })
            .toList(),
        'total': _total,
        'entryMethod': 'BARCODE',
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

  void _removeItem(int index) {
    setState(() => _scannedItems.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
        actions: [
          if (_scannedItems.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _done,
              child: const Text('Done'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Barcode input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    focusNode: _focusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter or scan barcode',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: const OutlineInputBorder(),
                      suffixIcon: _barcodeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _barcodeController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\dA-Za-z-]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _looking ? null : _lookup,
                  child: _looking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lookup'),
                ),
              ],
            ),
          ),

          if (_lookupError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lookupError!,
                  style: TextStyle(
                      color: Colors.orange.shade800, fontSize: 13),
                ),
              ),
            ),

          const Divider(height: 1),

          // Scanned items list
          if (_scannedItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Scan or enter barcodes\nto build your purchase list',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _scannedItems.length,
                itemBuilder: (context, index) {
                  final item = _scannedItems[index];
                  return Dismissible(
                    key: ValueKey('${item.barcode}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppTheme.errorColor,
                      child:
                          const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _removeItem(index),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.inventory_2,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        title: Text(item.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${item.barcode}  |  \u20B9${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SmallStepperButton(
                              icon: Icons.remove,
                              onTap: () {
                                if (item.quantity > 1) {
                                  setState(() => item.quantity -= 1);
                                }
                              },
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${item.quantity.toInt()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            _SmallStepperButton(
                              icon: Icons.add,
                              onTap: () =>
                                  setState(() => item.quantity += 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Bottom total bar
          if (_scannedItems.isNotEmpty)
            Container(
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
                        Text(
                            '${_scannedItems.length} item${_scannedItems.length == 1 ? '' : 's'}',
                            style: TextStyle(color: Colors.grey.shade600)),
                        Text(
                          '\u20B9${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _saving ? null : _done,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'Done'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallStepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _BarcodeItem {
  final String barcode;
  final String name;
  final double unitPrice;
  final String unit;
  double quantity;

  _BarcodeItem({
    required this.barcode,
    required this.name,
    required this.unitPrice,
    required this.unit,
    required this.quantity,
  });

  double get lineTotal => quantity * unitPrice;
}
