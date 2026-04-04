import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Templates', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Manage dispatch, receipt, and report templates', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _TemplateCard(
                    title: 'Receipt Template',
                    icon: Icons.receipt,
                    description: 'Customize receipt layout, header, footer, and fields shown',
                    onEdit: () {},
                  ),
                  _TemplateCard(
                    title: 'Dispatch Slip',
                    icon: Icons.local_shipping,
                    description: 'Template for dispatch slip printed at warehouse',
                    onEdit: () {},
                  ),
                  _TemplateCard(
                    title: 'Reconciliation Report',
                    icon: Icons.fact_check,
                    description: 'Daily reconciliation summary report format',
                    onEdit: () {},
                  ),
                  _TemplateCard(
                    title: 'Salary Slip',
                    icon: Icons.badge,
                    description: 'Monthly salary slip with deductions breakdown',
                    onEdit: () {},
                  ),
                  _TemplateCard(
                    title: 'Invoice',
                    icon: Icons.description,
                    description: 'GST-compliant invoice template for B2B customers',
                    onEdit: () {},
                  ),
                  _TemplateCard(
                    title: 'Daily Summary',
                    icon: Icons.summarize,
                    description: 'End-of-day summary sent to owner via WhatsApp/SMS',
                    onEdit: () {},
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

class _TemplateCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onEdit;

  const _TemplateCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
                  ),
                  const Spacer(),
                  Icon(Icons.edit, color: const Color(0xFF94A3B8), size: 18),
                ],
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
