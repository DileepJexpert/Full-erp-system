import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/business_provider.dart';
import '../../config/feature_flags.dart';
import 'sync_indicator.dart';

class OperatorScaffold extends ConsumerWidget {
  final Widget child;

  const OperatorScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final connectivity = ref.watch(connectivityProvider);
    final configAsync = ref.watch(businessConfigProvider);

    final tabs = configAsync.when(
      data: (config) => _buildTabs(config.features),
      loading: () => _defaultTabs,
      error: (_, __) => _defaultTabs,
    );

    final currentIndex = tabs.indexWhere((t) => currentPath.startsWith(t.path));

    final syncState = connectivity.when(
      data: (status) => status == ConnectivityStatus.online ? SyncState.synced : SyncState.offline,
      loading: () => SyncState.synced,
      error: (_, __) => SyncState.offline,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[currentIndex >= 0 ? currentIndex : 0].label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SyncIndicator(state: syncState, showLabel: true),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex >= 0 ? currentIndex : 0,
        onDestinationSelected: (index) => context.go(tabs[index].path),
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _OpTab {
  final IconData icon;
  final String label;
  final String path;
  const _OpTab(this.icon, this.label, this.path);
}

const _defaultTabs = [
  _OpTab(Icons.home, 'Home', '/op/home'),
  _OpTab(Icons.point_of_sale, 'Sell', '/op/sell'),
  _OpTab(Icons.inventory_2, 'Stock', '/op/stock'),
  _OpTab(Icons.account_balance_wallet, 'Salary', '/op/salary'),
];

List<_OpTab> _buildTabs(FeatureFlags f) {
  return [
    const _OpTab(Icons.home, 'Home', '/op/home'),
    const _OpTab(Icons.point_of_sale, 'Sell', '/op/sell'),
    const _OpTab(Icons.inventory_2, 'Stock', '/op/stock'),
    if (f.enableReconciliation)
      const _OpTab(Icons.fact_check, 'Reconcile', '/op/reconcile'),
    const _OpTab(Icons.account_balance_wallet, 'Salary', '/op/salary'),
    if (f.enableDelivery)
      const _OpTab(Icons.local_shipping, 'Deliver', '/op/delivery-proof'),
  ];
}
