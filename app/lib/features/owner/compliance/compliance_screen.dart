import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ComplianceScreen extends ConsumerWidget {
  const ComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compliance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('GST filing, FSSAI, and regulatory compliance tracking', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  _ComplianceCard(
                    title: 'GST Returns',
                    icon: Icons.receipt_long,
                    status: 'Filed',
                    statusColor: const Color(0xFF16A34A),
                    description: 'GSTR-1 and GSTR-3B filing status',
                  ),
                  _ComplianceCard(
                    title: 'FSSAI License',
                    icon: Icons.verified_user,
                    status: 'Active',
                    statusColor: const Color(0xFF16A34A),
                    description: 'Food safety license and renewal',
                  ),
                  _ComplianceCard(
                    title: 'Fire Safety',
                    icon: Icons.local_fire_department,
                    status: 'Due Soon',
                    statusColor: const Color(0xFFF59E0B),
                    description: 'Fire safety certificate renewal',
                  ),
                  _ComplianceCard(
                    title: 'Labour Compliance',
                    icon: Icons.people,
                    status: 'Compliant',
                    statusColor: const Color(0xFF16A34A),
                    description: 'PF, ESI, and labour law compliance',
                  ),
                  _ComplianceCard(
                    title: 'Shop License',
                    icon: Icons.store,
                    status: 'Active',
                    statusColor: const Color(0xFF16A34A),
                    description: 'Shop and establishment license',
                  ),
                  _ComplianceCard(
                    title: 'Health Inspection',
                    icon: Icons.health_and_safety,
                    status: 'Pending',
                    statusColor: const Color(0xFFEF4444),
                    description: 'Upcoming health inspection schedule',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplianceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String status;
  final Color statusColor;
  final String description;

  const _ComplianceCard({
    required this.title,
    required this.icon,
    required this.status,
    required this.statusColor,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2563EB), size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
