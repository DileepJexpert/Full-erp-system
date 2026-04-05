import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/business_provider.dart';

class _SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  final bool Function(dynamic)? featureCheck;
  final bool showBadge;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.featureCheck,
    this.showBadge = false,
  });
}

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final businessAsync = ref.watch(businessConfigProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCollapsed = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: isCollapsed ? 72 : 240,
            color: AppTheme.sidebarBg,
            child: Column(
              children: [
                // Header
                Container(
                  height: 64,
                  padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 20),
                  alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
                  child: isCollapsed
                      ? const Icon(Icons.business, color: Colors.white, size: 28)
                      : Text(
                          auth.user?.businessName ?? 'Business',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const Divider(color: Color(0xFF2D3348), height: 1),
                // Nav items
                Expanded(
                  child: businessAsync.when(
                    data: (config) => _buildNavItems(context, config, currentPath, isCollapsed),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => _buildNavItems(context, null, currentPath, isCollapsed),
                  ),
                ),
                const Divider(color: Color(0xFF2D3348), height: 1),
                // User info + logout
                _buildUserSection(context, ref, auth.user, isCollapsed),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        auth.user?.name ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          (auth.user?.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                // Page content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItems(BuildContext context, BusinessConfig? config, String currentPath, bool isCollapsed) {
    final features = config?.features;
    final items = <_SidebarItem>[
      const _SidebarItem(icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      if (features?.enableDispatch ?? true)
        const _SidebarItem(icon: Icons.send, label: 'Dispatch', route: '/dispatch'),
      if (features?.enableReconciliation ?? true)
        const _SidebarItem(icon: Icons.fact_check, label: 'Reconcile', route: '/reconcile'),
      const _SidebarItem(icon: Icons.inventory_2, label: 'Inventory', route: '/inventory'),
      const _SidebarItem(icon: Icons.receipt_long, label: 'Billing', route: '/billing'),
      const _SidebarItem(icon: Icons.account_balance_wallet, label: 'Salary', route: '/salary'),
      const _SidebarItem(icon: Icons.store, label: config?.locationLabel ?? 'Locations', route: '/locations'),
      const _SidebarItem(icon: Icons.people, label: 'Staff', route: '/staff'),
    ];

    final items2 = <_SidebarItem>[
      const _SidebarItem(icon: Icons.local_shipping, label: 'Suppliers', route: '/suppliers'),
      const _SidebarItem(icon: Icons.receipt, label: 'Expenses', route: '/expenses'),
      const _SidebarItem(icon: Icons.attach_money, label: 'Cash', route: '/cash'),
    ];

    final items3 = <_SidebarItem>[
      if (features?.enableAnomaly ?? true)
        const _SidebarItem(icon: Icons.warning_amber, label: 'Alerts', route: '/alerts', showBadge: true),
      if (features?.enablePerformance ?? true)
        const _SidebarItem(icon: Icons.leaderboard, label: 'Performance', route: '/performance'),
      const _SidebarItem(icon: Icons.verified, label: 'Compliance', route: '/compliance'),
      if (features?.enableLoyalty ?? false)
        const _SidebarItem(icon: Icons.card_giftcard, label: 'Loyalty', route: '/loyalty'),
      const _SidebarItem(icon: Icons.feedback, label: 'Feedback', route: '/feedback'),
      const _SidebarItem(icon: Icons.smart_toy, label: 'AI Advisor', route: '/ai'),
      const _SidebarItem(icon: Icons.auto_fix_high, label: 'Automation', route: '/automation'),
      const _SidebarItem(icon: Icons.account_balance, label: 'Budget', route: '/budget'),
      const _SidebarItem(icon: Icons.storefront, label: 'Marketplace', route: '/marketplace'),
      const _SidebarItem(icon: Icons.menu_book, label: 'Templates', route: '/templates'),
      const _SidebarItem(icon: Icons.bar_chart, label: 'Reports', route: '/reports'),
      const _SidebarItem(icon: Icons.settings, label: 'Settings', route: '/settings'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ...items.map((i) => _navTile(context, i, currentPath, isCollapsed)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Divider(color: Color(0xFF2D3348), height: 1),
        ),
        ...items2.map((i) => _navTile(context, i, currentPath, isCollapsed)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Divider(color: Color(0xFF2D3348), height: 1),
        ),
        ...items3.map((i) => _navTile(context, i, currentPath, isCollapsed)),
      ],
    );
  }

  Widget _navTile(BuildContext context, _SidebarItem item, String currentPath, bool isCollapsed) {
    final isActive = currentPath.startsWith(item.route);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isActive ? const Color(0xFF2563EB).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(item.route),
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive ? AppTheme.primaryColor : AppTheme.sidebarText,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppTheme.primaryColor : AppTheme.sidebarText,
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, WidgetRef ref, UserInfo? user, bool isCollapsed) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: isCollapsed
          ? IconButton(
              icon: const Icon(Icons.logout, color: AppTheme.sidebarText, size: 20),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF374151),
                  child: Text(
                    (user?.name ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.role ?? '',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  tooltip: 'Logout',
                ),
              ],
            ),
    );
  }
}
