import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../shared/formatters/currency.dart';

class UpiQrDisplay extends StatelessWidget {
  final String upiId;
  final double amount;
  final String payeeName;

  const UpiQrDisplay({
    super.key,
    required this.upiId,
    required this.amount,
    required this.payeeName,
  });

  String get _upiUrl =>
      'upi://pay?pa=$upiId&pn=$payeeName&am=${amount.toStringAsFixed(2)}&cu=INR';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Scan to Pay', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: QrImageView(
            data: _upiUrl,
            version: QrVersions.auto,
            size: 200,
          ),
        ),
        const SizedBox(height: 12),
        Text(formatRupee(amount), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(upiId, style: const TextStyle(color: Color(0xFF94A3B8))),
      ],
    );
  }
}
