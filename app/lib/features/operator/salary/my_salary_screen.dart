import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'my_salary_provider.dart';

class MySalaryScreen extends ConsumerWidget {
  const MySalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(mySalaryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mySalaryProvider),
      child: salaryAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LoadingSkeleton.card(),
          )),
        ),
        error: (err, _) => ListView(
          children: [
            ErrorView(
              message: 'Failed to load salary: $err',
              onRetry: () => ref.invalidate(mySalaryProvider),
            ),
          ],
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month title
            Text(
              _formatMonthTitle(data.current.month),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
            ),
            const SizedBox(height: 16),

            // Net Salary - prominent card
            _NetSalaryCard(salary: data.current),
            const SizedBox(height: 16),

            // Breakdown cards
            _BreakdownRow(
              children: [
                _SalaryComponent(
                  label: 'Base Salary',
                  amount: data.current.baseSalary,
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF2563EB),
                ),
                _SalaryComponent(
                  label: 'Bonus',
                  amount: data.current.bonus,
                  icon: Icons.star,
                  color: const Color(0xFF16A34A),
                  showPlus: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BreakdownRow(
              children: [
                _SalaryComponent(
                  label: 'Loss Deductions',
                  amount: data.current.lossDeductions,
                  icon: Icons.trending_down,
                  color: const Color(0xFFDC2626),
                  isDeduction: true,
                ),
                _SalaryComponent(
                  label: 'Cash Shortfall',
                  amount: data.current.cashShortfall,
                  icon: Icons.money_off,
                  color: const Color(0xFFDC2626),
                  isDeduction: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BreakdownRow(
              children: [
                _SalaryComponent(
                  label: 'Advances',
                  amount: data.current.advances,
                  icon: Icons.payments,
                  color: const Color(0xFFD97706),
                  isDeduction: true,
                ),
              ],
            ),

            // Payment status
            if (data.current.status == 'PAID' &&
                data.current.paidOn != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Paid on ${formatDate(data.current.paidOn!)}',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                  ],
                ),
              ),
            ],

            // History section
            if (data.history.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Past Months',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ...data.history.map((salary) => _HistoryTile(salary: salary)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatMonthTitle(String month) {
    // month format: "2026-04" or similar
    final parts = month.split('-');
    if (parts.length >= 2) {
      final year = parts[0];
      final m = int.tryParse(parts[1]) ?? 1;
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[m]} $year';
    }
    return month;
  }
}

class _NetSalaryCard extends StatelessWidget {
  final SalaryBreakdown salary;

  const _NetSalaryCard({required this.salary});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (salary.status) {
      'PAID' => const Color(0xFF16A34A),
      'PARTIAL' => const Color(0xFFD97706),
      _ => const Color(0xFF64748B),
    };
    final statusLabel = switch (salary.status) {
      'PAID' => 'Paid',
      'PARTIAL' => 'Partially Paid',
      _ => 'Pending',
    };

    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Salary',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatRupee(salary.netSalary),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final List<Widget> children;

  const _BreakdownRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((child) => [Expanded(child: child)])
          .toList()
        ..insertAll(
          1,
          children.length > 1
              ? List.generate(
                  children.length - 1, (_) => const SizedBox(width: 12))
              : [],
        ),
    );
  }
}

class _SalaryComponent extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isDeduction;
  final bool showPlus;

  const _SalaryComponent({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.isDeduction = false,
    this.showPlus = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = isDeduction && amount > 0
        ? '- ${formatRupee(amount)}'
        : showPlus && amount > 0
            ? '+ ${formatRupee(amount)}'
            : formatRupee(amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              displayAmount,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDeduction && amount > 0 ? color : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SalaryBreakdown salary;

  const _HistoryTile({required this.salary});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (salary.status) {
      'PAID' => const Color(0xFF16A34A),
      'PARTIAL' => const Color(0xFFD97706),
      _ => const Color(0xFF64748B),
    };
    final statusLabel = switch (salary.status) {
      'PAID' => 'Paid',
      'PARTIAL' => 'Partial',
      _ => 'Pending',
    };

    // Parse month string for display
    String monthLabel = salary.month;
    final parts = salary.month.split('-');
    if (parts.length >= 2) {
      final dt = DateTime.tryParse('${salary.month}-01');
      if (dt != null) {
        monthLabel = formatMonth(dt);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          monthLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Row(
          children: [
            Text(
              'Base: ${formatRupee(salary.baseSalary)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
            ),
            if (salary.lossDeductions > 0) ...[
              const SizedBox(width: 8),
              Text(
                'Loss: -${formatRupee(salary.lossDeductions)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFDC2626),
                    ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatRupee(salary.netSalary),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
