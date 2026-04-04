import 'package:flutter/material.dart';
import '../../../../shared/formatters/currency.dart';

class BillSummary extends StatelessWidget {
  final Map<String, dynamic> bill;
  const BillSummary({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 12),
            Text('Bill Saved!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Bill #${bill['billNumber'] ?? ''}', style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            Text(
              formatRupee((bill['total'] ?? 0).toDouble()),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Payment: ${bill['paymentMode'] ?? 'CASH'}', style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
