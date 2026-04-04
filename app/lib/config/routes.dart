import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_provider.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/operator_scaffold.dart';

// Auth screens
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';

// Owner screens
import '../features/owner/dashboard/dashboard_screen.dart';
import '../features/owner/dispatch/dispatch_list_screen.dart';
import '../features/owner/dispatch/dispatch_create_screen.dart';
import '../features/owner/reconciliation/recon_list_screen.dart';
import '../features/owner/reconciliation/recon_detail_screen.dart';
import '../features/owner/inventory/items_screen.dart';
import '../features/owner/inventory/item_form_screen.dart';
import '../features/owner/billing/bills_list_screen.dart';
import '../features/owner/salary/salary_screen.dart';
import '../features/owner/locations/locations_screen.dart';
import '../features/owner/locations/location_form_screen.dart';
import '../features/owner/staff/staff_screen.dart';
import '../features/owner/staff/staff_form_screen.dart';
import '../features/owner/suppliers/suppliers_screen.dart';
import '../features/owner/suppliers/purchase_form_screen.dart';
import '../features/owner/expenses/expenses_screen.dart';
import '../features/owner/cash/cash_collection_screen.dart';
import '../features/owner/alerts/alerts_screen.dart';
import '../features/owner/performance/performance_screen.dart';
import '../features/owner/compliance/compliance_screen.dart';
import '../features/owner/loyalty/loyalty_screen.dart';
import '../features/owner/templates/templates_screen.dart';
import '../features/owner/reports/reports_screen.dart';
import '../features/owner/settings/settings_screen.dart';

// Operator screens
import '../features/operator/home/operator_home_screen.dart';
import '../features/operator/pos/pos_screen.dart';
import '../features/operator/reconcile/reconcile_screen.dart';
import '../features/operator/salary/my_salary_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/otp';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        final role = authState.user?.role ?? '';
        if (role == 'STAFF') return '/op/home';
        return '/dashboard';
      }

      // Prevent staff from accessing owner routes
      if (isLoggedIn && authState.user?.isStaff == true) {
        if (!state.matchedLocation.startsWith('/op')) return '/op/home';
      }

      // Prevent owner from accidentally going to operator routes
      if (isLoggedIn && authState.user?.isOwner == true) {
        if (state.matchedLocation.startsWith('/op')) return '/dashboard';
      }

      return null;
    },
    routes: [
      // Auth
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (_, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OtpScreen(phone: phone);
      }),

      // Owner/Manager shell
      ShellRoute(
        builder: (_, __, child) => AppScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/dispatch', builder: (_, __) => const DispatchListScreen()),
          GoRoute(path: '/dispatch/create', builder: (_, __) => const DispatchCreateScreen()),
          GoRoute(path: '/reconcile', builder: (_, __) => const ReconListScreen()),
          GoRoute(path: '/reconcile/:id', builder: (_, state) =>
            ReconDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/inventory', builder: (_, __) => const ItemsScreen()),
          GoRoute(path: '/inventory/new', builder: (_, __) => const ItemFormScreen()),
          GoRoute(path: '/inventory/:id', builder: (_, state) =>
            ItemFormScreen(id: state.pathParameters['id'])),
          GoRoute(path: '/billing', builder: (_, __) => const BillsListScreen()),
          GoRoute(path: '/salary', builder: (_, __) => const SalaryScreen()),
          GoRoute(path: '/locations', builder: (_, __) => const LocationsScreen()),
          GoRoute(path: '/locations/new', builder: (_, __) => const LocationFormScreen()),
          GoRoute(path: '/locations/:id', builder: (_, state) =>
            LocationFormScreen(id: state.pathParameters['id'])),
          GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
          GoRoute(path: '/staff/new', builder: (_, __) => const StaffFormScreen()),
          GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersScreen()),
          GoRoute(path: '/suppliers/purchase', builder: (_, __) => const PurchaseFormScreen()),
          GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
          GoRoute(path: '/cash', builder: (_, __) => const CashCollectionScreen()),
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
          GoRoute(path: '/performance', builder: (_, __) => const PerformanceScreen()),
          GoRoute(path: '/compliance', builder: (_, __) => const ComplianceScreen()),
          GoRoute(path: '/loyalty', builder: (_, __) => const LoyaltyScreen()),
          GoRoute(path: '/templates', builder: (_, __) => const TemplatesScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),

      // Operator shell
      ShellRoute(
        builder: (_, __, child) => OperatorScaffold(child: child),
        routes: [
          GoRoute(path: '/op/home', builder: (_, __) => const OperatorHomeScreen()),
          GoRoute(path: '/op/sell', builder: (_, __) => const PosScreen()),
          GoRoute(path: '/op/reconcile', builder: (_, __) => const ReconcileScreen()),
          GoRoute(path: '/op/salary', builder: (_, __) => const MySalaryScreen()),
        ],
      ),
    ],
  );
});
