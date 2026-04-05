import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../purchase_provider.dart';

/// Scan multiple bills in sequence, then save them all at once.
class BatchScanScreen extends ConsumerStatefulWidget {
  const BatchScanScreen({super.key});

  @override
  ConsumerState<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends ConsumerState<BatchScanScreen> {
  final _picker = ImagePicker();
  final _pageController = PageController();
  final _bills = <_ScannedBill>[];
  bool _scanning = false;
  bool _saving = false;

  double get _totalAmount =>
      _bills.fold(0.0, (sum, b) => sum + (b.total));

  Future<void> _scanBill() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null) return;

      setState(() => _scanning = true);

      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final api = ref.read(apiClientProvider);
      final response = await api.post('/purchases/scan-bill', data: {
        'image': base64Image,
      });
      final data = response.data as Map<String, dynamic>;
      final extracted = data['data'] as Map<String, dynamic>;

      final items =
          (extracted['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final total = items.fold<double>(0.0, (sum, item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
        return sum + qty * price;
      });

      setState(() {
        _bills.add(_ScannedBill(
          supplierName: extracted['supplierName'] as String? ?? 'Unknown',
          itemCount: items.length,
          total: total,
          data: extracted,
          imagePath: photo.path,
        ));
      });

      // Jump to the newly added page
      _pageController.animateToPage(
        _bills.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _saveAll() async {
    if (_bills.isEmpty) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);
      final purchases = _bills.map((b) => b.data).toList();
      await batchSavePurchases(api, purchases);

      if (mounted) {
        ref.invalidate(todayPurchasesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_bills.length} purchases saved successfully')),
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

  void _editBill(int index) {
    context.push('/purchases/scan/review', extra: _bills[index].data);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Scan'),
        actions: [
          if (_bills.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _saveAll,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save All'),
            ),
        ],
      ),
      body: _bills.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // Page view of scanned bills
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _bills.length + 1, // +1 for "add more" page
                    itemBuilder: (context, index) {
                      if (index == _bills.length) {
                        return _buildAddMorePage(context);
                      }
                      return _buildBillPage(context, index);
                    },
                  ),
                ),

                // Page indicator
                if (_bills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_bills.length + 1, (i) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade400,
                          ),
                        );
                      }),
                    ),
                  ),

                // Summary bar
                if (_bills.isNotEmpty) _buildSummaryBar(context),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: _scanning
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning bill...'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.document_scanner,
                    size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Scan multiple bills',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture each supplier bill one by one,\nthen save them all at once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _scanBill,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan First Bill'),
                ),
              ],
            ),
    );
  }

  Widget _buildBillPage(BuildContext context, int index) {
    final bill = _bills[index];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt, size: 48, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Bill ${index + 1}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                bill.supplierName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _InfoRow(label: 'Items', value: '${bill.itemCount}'),
              const SizedBox(height: 8),
              _InfoRow(
                  label: 'Total',
                  value: '\u20B9${bill.total.toStringAsFixed(2)}'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _editBill(index),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Review & Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMorePage(BuildContext context) {
    return Center(
      child: _scanning
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning...'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.large(
                  heroTag: 'batch_add',
                  onPressed: _scanBill,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.add_a_photo,
                      size: 36, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text('Scan Next Bill'),
              ],
            ),
    );
  }

  Widget _buildSummaryBar(BuildContext context) {
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
                Text('${_bills.length} bill${_bills.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Total: \u20B9${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _saveAll,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save All'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ScannedBill {
  final String supplierName;
  final int itemCount;
  final double total;
  final Map<String, dynamic> data;
  final String imagePath;

  const _ScannedBill({
    required this.supplierName,
    required this.itemCount,
    required this.total,
    required this.data,
    required this.imagePath,
  });
}
