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

// V3 Enhancement screens
import '../features/owner/ai/ai_chat_screen.dart';
import '../features/owner/ai/insights_screen.dart';
import '../features/owner/budget/budget_screen.dart';
import '../features/owner/automation/rules_screen.dart';
import '../features/owner/reports/scheduled_reports_screen.dart';
import '../features/owner/staff/leave_screen.dart';
import '../features/owner/staff/shift_screen.dart';
import '../features/owner/settings/audit_screen.dart';
import '../features/owner/marketplace/browse_screen.dart';
import '../features/owner/marketplace/order_screen.dart';
import '../features/owner/loyalty/segments_screen.dart';
import '../features/owner/loyalty/feedback_screen.dart';
import '../features/owner/inventory/transfer_screen.dart';

// Purchase system screens
import '../features/purchases/scan/bill_camera_screen.dart';
import '../features/purchases/scan/scan_review_screen.dart';
import '../features/purchases/scan/batch_scan_screen.dart';
import '../features/purchases/voice/voice_entry_screen.dart';
import '../features/purchases/repeat/repeat_purchase_screen.dart';
import '../features/purchases/barcode/barcode_scanner_screen.dart';
import '../features/purchases/templates/purchase_templates_screen.dart';
import '../features/owner/purchases/approval_screen.dart';
import '../features/owner/settings/aliases_screen.dart';
import '../features/operator/stock/stock_tab_screen.dart';

// Kiosk screens
import '../features/kiosk/kiosk_setup_screen.dart';
import '../features/kiosk/kiosk_feedback_screen.dart';

// Owner feedback dashboard (kiosk analytics)
import '../features/owner/feedback/feedback_dashboard_screen.dart'
    as kiosk_feedback;

// Operator screens
import '../features/operator/home/operator_home_screen.dart';
import '../features/operator/pos/pos_screen.dart';
import '../features/operator/reconcile/reconcile_screen.dart';
import '../features/operator/salary/my_salary_screen.dart';
import '../features/operator/leave/leave_request_screen.dart';

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
          GoRoute(path: '/reports/scheduled', builder: (_, __) => const ScheduledReportsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/settings/audit', builder: (_, __) => const AuditScreen()),
          // V3 routes
          GoRoute(path: '/ai', builder: (_, __) => const AiChatScreen()),
          GoRoute(path: '/ai/insights', builder: (_, __) => const InsightsScreen()),
          GoRoute(path: '/budget', builder: (_, __) => const BudgetScreen()),
          GoRoute(path: '/automation', builder: (_, __) => const RulesScreen()),
          GoRoute(path: '/staff/leave', builder: (_, __) => const LeaveScreen()),
          GoRoute(path: '/staff/shifts', builder: (_, __) => const ShiftScreen()),
          GoRoute(path: '/marketplace', builder: (_, __) => const MarketplaceBrowseScreen()),
          GoRoute(path: '/marketplace/orders', builder: (_, __) => const MarketplaceOrderScreen()),
          GoRoute(path: '/loyalty/segments', builder: (_, __) => const SegmentsScreen()),
          // /loyalty/feedback kept as alias for backwards compatibility
          GoRoute(path: '/loyalty/feedback', builder: (_, __) => const FeedbackDashboardScreen()),
          GoRoute(path: '/inventory/transfer', builder: (_, __) => const StockTransferScreen()),
          // Smart purchase system routes
          GoRoute(path: '/purchases/scan', builder: (_, __) => const BillCameraScreen()),
          GoRoute(path: '/purchases/scan/review', builder: (_, state) {
            final data = state.extra as Map<String, dynamic>? ?? {};
            return ScanReviewScreen(extractedData: data);
          }),
          GoRoute(path: '/purchases/scan/batch', builder: (_, __) => const BatchScanScreen()),
          GoRoute(path: '/purchases/voice', builder: (_, __) => const VoiceEntryScreen()),
          GoRoute(path: '/purchases/repeat', builder: (_, __) => const RepeatPurchaseScreen()),
          GoRoute(path: '/purchases/barcode', builder: (_, __) => const BarcodeScannerScreen()),
          GoRoute(path: '/purchases/templates', builder: (_, __) => const PurchaseTemplatesScreen()),
          GoRoute(path: '/purchases/approvals', builder: (_, __) => const PurchaseApprovalScreen()),
          GoRoute(path: '/settings/aliases', builder: (_, __) => const AliasesScreen()),
          // Kiosk routes
          GoRoute(path: '/feedback', builder: (_, __) => const kiosk_feedback.FeedbackDashboardScreen()),
          GoRoute(path: '/kiosk/setup', builder: (_, __) => const KioskSetupScreen()),
        ],
      ),

      // Kiosk mode (standalone, outside shell routes)
      GoRoute(path: '/kiosk/feedback', builder: (_, __) => const KioskFeedbackScreen()),

      // Operator shell
      ShellRoute(
        builder: (_, __, child) => OperatorScaffold(child: child),
        routes: [
          GoRoute(path: '/op/home', builder: (_, __) => const OperatorHomeScreen()),
          GoRoute(path: '/op/sell', builder: (_, __) => const PosScreen()),
          GoRoute(path: '/op/stock', builder: (_, __) => const StockTabScreen()),
          GoRoute(path: '/op/reconcile', builder: (_, __) => const ReconcileScreen()),
          GoRoute(path: '/op/salary', builder: (_, __) => const MySalaryScreen()),
          GoRoute(path: '/op/leave', builder: (_, __) => const LeaveRequestScreen()),
        ],
      ),
    ],
  );
});
