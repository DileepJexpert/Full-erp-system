import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../core/providers/business_provider.dart';
import 'dashboard_provider.dart';
import 'widgets/location_status_table.dart';
import 'widgets/alerts_panel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final configAsync = ref.watch(businessConfigProvider);
    final businessType = configAsync.when(data: (c) => c.type, loading: () => '', error: (_, __) => '');
    final features = configAsync.when(data: (c) => c.features, loading: () => null, error: (_, __) => null);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: dashboardAsync.when(
          loading: () => _buildLoadingSkeleton(),
          error: (err, _) => ErrorView(message: err.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Today\'s overview', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
              const SizedBox(height: 24),
              // Stat cards grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1200 ? 4 : constraints.maxWidth > 800 ? 3 : 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Universal cards
                      _card(constraints, crossAxisCount, StatCard(title: 'Today\'s Revenue', value: formatRupee(data.todayRevenue), subtitle: '${data.todayBillCount} bills', icon: Icons.trending_up, iconColor: const Color(0xFF16A34A))),
                      _card(constraints, crossAxisCount, StatCard(title: 'Active Locations', value: '${data.activeLocations}', icon: Icons.store, iconColor: const Color(0xFF2563EB))),
                      // Dispatch-dependent
                      if (features?.enableDispatch ?? false)
                        _card(constraints, crossAxisCount, StatCard(title: 'Pending Dispatch', value: '${data.pendingDispatches}', subtitle: '${data.unreconciledDispatches} unreconciled', icon: Icons.send, iconColor: const Color(0xFFEAB308))),
                      // Cash is universal
                      _card(constraints, crossAxisCount, StatCard(title: 'Cash Collected', value: formatRupee(data.cashCollectedToday), subtitle: data.cashShortageToday > 0 ? 'Shortage: ${formatRupee(data.cashShortageToday)}' : 'No shortage', icon: Icons.attach_money, iconColor: const Color(0xFF16A34A))),
                      // Loss only for food-type businesses
                      if (['FOOD_KIOSK', 'CLOUD_KITCHEN', 'BAKERY'].contains(businessType))
                        _card(constraints, crossAxisCount, StatCard(title: 'Month Loss', value: formatRupee(data.totalLossThisMonth), icon: Icons.warning, iconColor: const Color(0xFFDC2626))),
                      // Expenses universal
                      _card(constraints, crossAxisCount, StatCard(title: 'Today Expenses', value: formatRupee(data.todayExpenses), icon: Icons.receipt, iconColor: const Color(0xFF64748B))),
                      // Alerts conditional
                      if (features?.enableAnomaly ?? false)
                        _card(constraints, crossAxisCount, StatCard(title: 'Unread Alerts', value: '${data.unreadAlerts}', icon: Icons.notifications_active, iconColor: data.unreadAlerts > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
                      // Appointment count for service businesses
                      if (features?.enableAppointments ?? false)
                        _card(constraints, crossAxisCount, StatCard(title: 'Today\'s Appointments', value: '${data.todayAppointments ?? 0}', icon: Icons.calendar_today, iconColor: const Color(0xFF7C3AED))),
                      // Credit outstanding for credit businesses
                      if (features?.enableCreditLedger ?? false)
                        _card(constraints, crossAxisCount, StatCard(title: 'Credit Outstanding', value: formatRupee(data.totalCreditOutstanding ?? 0), icon: Icons.account_balance, iconColor: const Color(0xFFEA580C))),
                      // Delivery count for delivery businesses
                      if (features?.enableDelivery ?? false)
                        _card(constraints, crossAxisCount, StatCard(title: 'Pending Deliveries', value: '${data.pendingDeliveries ?? 0}', icon: Icons.local_shipping, iconColor: const Color(0xFF0891B2))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              // Location stats table
              Text('Location Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const LocationStatusTable(),
              const SizedBox(height: 32),
              // Alerts panel
              Text('Recent Alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const AlertsPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BoxConstraints constraints, int crossAxisCount, Widget child) {
    final width = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
    return SizedBox(width: width, child: child);
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LoadingSkeleton(width: 200, height: 32),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(6, (_) => SizedBox(width: 280, child: LoadingSkeleton.card())),
        ),
      ],
    );
  }
}
