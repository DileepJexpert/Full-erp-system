import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/stat_card.dart';
import 'operator_home_provider.dart';

class OperatorHomeScreen extends ConsumerWidget {
  const OperatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final summaryAsync = ref.watch(operatorSummaryProvider);
    final userName = auth.user?.name ?? 'Operator';
    final greeting = _greeting();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(operatorSummaryProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting
          Text(
            '$greeting,',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),

          // Attendance card
          summaryAsync.when(
            loading: () => LoadingSkeleton.card(),
            error: (err, _) => ErrorView(
              message: 'Failed to load summary: $err',
              onRetry: () => ref.invalidate(operatorSummaryProvider),
            ),
            data: (summary) => Column(
              children: [
                _AttendanceCard(summary: summary),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: "Today's Revenue",
                        value: formatRupee(summary.todayRevenue),
                        icon: Icons.currency_rupee,
                        iconColor: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Bills Count',
                        value: '${summary.billCount}',
                        icon: Icons.receipt_long,
                        iconColor: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatCard(
                  title: 'Pending Reconciliation',
                  value: '${summary.pendingRecon}',
                  subtitle: summary.pendingRecon > 0
                      ? 'Items awaiting reconciliation'
                      : 'All caught up!',
                  icon: Icons.fact_check,
                  iconColor: summary.pendingRecon > 0
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF16A34A),
                ),
                const SizedBox(height: 24),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.point_of_sale,
                        label: 'New Sale',
                        color: const Color(0xFF16A34A),
                        onTap: () => context.go('/op/sell'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.fact_check,
                        label: 'Reconcile',
                        color: const Color(0xFF2563EB),
                        onTap: () => context.go('/op/reconcile'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _AttendanceCard extends ConsumerWidget {
  final TodaySummary summary;

  const _AttendanceCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(attendanceActionProvider);
    final isLoading = actionState is AsyncLoading;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (summary.isCheckedIn) {
      statusColor = const Color(0xFF16A34A);
      statusText = 'Checked In';
      statusIcon = Icons.check_circle;
    } else if (summary.isCheckedOut) {
      statusColor = const Color(0xFF64748B);
      statusText = 'Checked Out';
      statusIcon = Icons.logout;
    } else {
      statusColor = const Color(0xFFEA580C);
      statusText = 'Not Checked In';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  formatDate(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                ),
              ],
            ),
            if (summary.checkInTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Checked in at ${formatTime(summary.checkInTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
            ],
            if (summary.checkOutTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Checked out at ${formatTime(summary.checkOutTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: isLoading || summary.isCheckedOut
                    ? null
                    : () => _handleAttendance(context, ref),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(summary.isCheckedIn ? Icons.logout : Icons.login),
                label: Text(
                  summary.isCheckedIn
                      ? 'Check Out'
                      : summary.isCheckedOut
                          ? 'Done for Today'
                          : 'Check In',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: summary.isCheckedIn
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF16A34A),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAttendance(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(attendanceActionProvider.notifier);
    final bool success;

    if (summary.isCheckedIn) {
      success = await notifier.checkOut();
    } else {
      success = await notifier.checkIn();
    }

    if (success && context.mounted) {
      ref.invalidate(operatorSummaryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary.isCheckedIn
                ? 'Checked out successfully'
                : 'Checked in successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
