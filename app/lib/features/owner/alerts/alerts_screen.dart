import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import 'alerts_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(filteredAlertsProvider);
    final currentFilter = ref.watch(alertFilterProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(alertsProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Alerts',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      if (unreadCount > 0)
                        Badge(
                          label: Text('$unreadCount'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          child: const Icon(Icons.notifications_active, size: 28),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Business alerts and notifications',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: currentFilter == null,
                          onTap: () => ref.read(alertFilterProvider.notifier).state = null,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Critical',
                          selected: currentFilter == AlertSeverity.critical,
                          color: const Color(0xFFDC2626),
                          onTap: () => ref.read(alertFilterProvider.notifier).state = AlertSeverity.critical,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Warning',
                          selected: currentFilter == AlertSeverity.warning,
                          color: const Color(0xFFF59E0B),
                          onTap: () => ref.read(alertFilterProvider.notifier).state = AlertSeverity.warning,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Info',
                          selected: currentFilter == AlertSeverity.info,
                          color: const Color(0xFF2563EB),
                          onTap: () => ref.read(alertFilterProvider.notifier).state = AlertSeverity.info,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          alertsAsync.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LoadingSkeleton.card(),
                  ),
                  childCount: 5,
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              child: ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(alertsProvider),
              ),
            ),
            data: (alerts) {
              if (alerts.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No alerts',
                    subtitle: 'Everything looks good!',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final alert = alerts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AlertCard(alert: alert),
                      );
                    },
                    childCount: alerts.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color?.withOpacity(0.15) ?? Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: color ?? Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? (color ?? Theme.of(context).colorScheme.primary) : null,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final Alert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderColor = switch (alert.severity) {
      AlertSeverity.critical => const Color(0xFFDC2626),
      AlertSeverity.warning => const Color(0xFFF59E0B),
      AlertSeverity.info => const Color(0xFF2563EB),
    };

    final icon = switch (alert.type) {
      AlertType.HIGH_WASTAGE => Icons.delete_outline,
      AlertType.CASH_MISMATCH => Icons.account_balance_wallet_outlined,
      AlertType.LATE_OPENING => Icons.access_time,
      AlertType.LOW_STOCK => Icons.inventory_2_outlined,
      AlertType.EXPENSE_LIMIT => Icons.money_off,
      AlertType.ATTENDANCE_ISSUE => Icons.person_off_outlined,
      AlertType.DISPATCH_DELAY => Icons.local_shipping_outlined,
      AlertType.UNKNOWN => Icons.info_outline,
    };

    final timeAgo = _formatTimeAgo(alert.createdAt);

    return Card(
      elevation: alert.isRead ? 0 : 1,
      color: alert.isRead ? null : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE2E8F0), width: alert.isRead ? 1 : 0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (!alert.isRead) {
            await markAlertAsRead(ref, alert.id);
          }
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: borderColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.message,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: alert.isRead ? FontWeight.w400 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  alert.locationName,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time, size: 14, color: const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  timeAgo,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: borderColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
