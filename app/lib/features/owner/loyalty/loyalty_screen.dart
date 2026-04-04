import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/formatters/currency.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loyalty Program', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Manage customer loyalty points and rewards', style: TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Configure'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Stats cards
            Row(
              children: [
                _statCard('Total Members', '0', Icons.people, const Color(0xFF2563EB)),
                const SizedBox(width: 16),
                _statCard('Points Issued', '0', Icons.stars, const Color(0xFFF59E0B)),
                const SizedBox(width: 16),
                _statCard('Points Redeemed', '0', Icons.redeem, const Color(0xFF16A34A)),
              ].map((w) => Expanded(child: w)).toList(),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard, size: 64, color: const Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      const Text('Loyalty program not configured', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      const Text('Set up points rules and rewards to get started', style: TextStyle(color: Color(0xFF94A3B8))),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Set Up Loyalty Program'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
