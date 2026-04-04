import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/connectivity_provider.dart';
import 'sync_indicator.dart';

class OperatorScaffold extends ConsumerWidget {
  final Widget child;

  const OperatorScaffold({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home, label: 'Home', path: '/op/home'),
    (icon: Icons.point_of_sale, label: 'Sell', path: '/op/sell'),
    (icon: Icons.fact_check, label: 'Reconcile', path: '/op/reconcile'),
    (icon: Icons.account_balance_wallet, label: 'Salary', path: '/op/salary'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final currentIndex = _tabs.indexWhere((t) => currentPath.startsWith(t.path));
    final connectivity = ref.watch(connectivityProvider);

    final syncState = connectivity.when(
      data: (status) => status == ConnectivityStatus.online ? SyncState.synced : SyncState.offline,
      loading: () => SyncState.synced,
      error: (_, __) => SyncState.offline,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[currentIndex >= 0 ? currentIndex : 0].label),
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
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _tabs
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
