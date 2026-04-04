import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'leave_provider.dart';

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(leaveRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave Management'),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved / Rejected'),
            ],
          ),
        ),
        body: leavesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LoadingSkeleton(height: 100),
              ),
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(leaveRequestsProvider),
          ),
          data: (leaves) {
            final pending = leaves
                .where((l) =>
                    (l['status'] ?? '').toString().toLowerCase() == 'pending')
                .toList();
            final resolved = leaves
                .where((l) =>
                    (l['status'] ?? '').toString().toLowerCase() != 'pending')
                .toList();

            return TabBarView(
              children: [
                _buildList(context, ref, pending, showActions: true),
                _buildList(context, ref, resolved, showActions: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> leaves,
      {required bool showActions}) {
    if (leaves.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: EmptyState(
          icon: Icons.event_available_outlined,
          title: 'No leave requests',
          subtitle: 'Leave requests will appear here.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(leaveRequestsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: leaves.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final leave = leaves[index];
          return _LeaveCard(
            leave: leave,
            showActions: showActions,
            onApprove: () => approveLeave(ref, leave['id'].toString()),
            onReject: () => rejectLeave(ref, leave['id'].toString()),
          );
        },
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _LeaveCard({
    required this.leave,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  Color _leaveTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'casual':
        return const Color(0xFF2563EB);
      case 'sick':
        return const Color(0xFFDC2626);
      case 'earned':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffName =
        leave['staffName'] ?? leave['staff']?['name'] ?? 'Unknown';
    final leaveType = (leave['leaveType'] ?? leave['type'] ?? '').toString();
    final status = (leave['status'] ?? 'pending').toString();
    final reason = leave['reason'] ?? '';
    final startDate = DateTime.tryParse((leave['startDate'] ?? '').toString());
    final endDate = DateTime.tryParse((leave['endDate'] ?? '').toString());
    final days = leave['days'] ??
        (startDate != null && endDate != null
            ? endDate.difference(startDate).inDays + 1
            : 0);

    final typeColor = _leaveTypeColor(leaveType);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                  child: Text(
                    staffName.isNotEmpty ? staffName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staffName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              leaveType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ),
                          if (!showActions) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$days day${days == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  startDate != null && endDate != null
                      ? '${formatDate(startDate)} - ${formatDate(endDate)}'
                      : '-',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF64748B)),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reason,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
