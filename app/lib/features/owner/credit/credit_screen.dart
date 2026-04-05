import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final creditSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/credit/summary');
  return response.data as Map<String, dynamic>;
});

final creditCustomersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/credit/customers');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final creditHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, customerId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/credit/customers/$customerId/history');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────

class CreditScreen extends ConsumerWidget {
  const CreditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(creditSummaryProvider);
    final customersAsync = ref.watch(creditCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Ledger'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordPaymentSheet(context, ref),
        icon: const Icon(Icons.payment),
        label: const Text('Record Payment'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(creditSummaryProvider);
          ref.invalidate(creditCustomersProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total outstanding card
              summaryAsync.when(
                loading: () => const LoadingSkeleton(height: 100),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) {
                  final total =
                      (summary['totalOutstanding'] ?? 0).toDouble();
                  return Card(
                    elevation: 0,
                    color: const Color(0xFFFEE2E2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Total Outstanding',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatRupee(total),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          if (summary['customerCount'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${summary['customerCount']} customers with credit',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Customers',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              // Customer list
              customersAsync.when(
                loading: () => Column(
                  children: List.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton.card(),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(creditCustomersProvider),
                ),
                data: (customers) {
                  if (customers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No credit customers',
                      subtitle: 'Customers with outstanding credit will appear here.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      return _CreditCustomerCard(
                        customer: c,
                        onTap: () => _showCustomerHistory(context, ref, c),
                        onSendReminder: () =>
                            _sendReminder(context, ref, c),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerHistory(
      BuildContext context, WidgetRef ref, Map<String, dynamic> customer) {
    final customerId =
        (customer['id'] ?? customer['customerId'] ?? '').toString();
    final name = customer['name'] ?? customer['customerName'] ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Consumer(
          builder: (ctx, ref, _) {
            final historyAsync = ref.watch(creditHistoryProvider(customerId));
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Outstanding: ${formatRupee((customer['outstanding'] ?? customer['balance'] ?? 0).toDouble())}',
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 24),
                Text(
                  'Transaction History',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                historyAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Text('Error: $err'),
                  data: (history) {
                    if (history.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No transactions found.'),
                      );
                    }
                    double runningBalance = 0;
                    return Column(
                      children: history.map((tx) {
                        final type = tx['type'] ?? 'CREDIT';
                        final amount = (tx['amount'] ?? 0).toDouble();
                        final isCredit = type == 'CREDIT' || type == 'SALE';
                        runningBalance +=
                            isCredit ? amount : -amount;
                        final date = DateTime.tryParse(
                            tx['date'] ?? tx['createdAt'] ?? '');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                isCredit
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 18,
                                color: isCredit
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx['description'] ?? type,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (date != null)
                                      Text(
                                        formatDate(date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isCredit ? '+' : '-'}${formatRupee(amount)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isCredit
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
                                    ),
                                  ),
                                  Text(
                                    'Bal: ${formatRupee(runningBalance)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendReminder(
      BuildContext context, WidgetRef ref, Map<String, dynamic> customer) async {
    try {
      final api = ref.read(apiClientProvider);
      final customerId =
          (customer['id'] ?? customer['customerId'] ?? '').toString();
      await api.post('/credit/customers/$customerId/remind');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRecordPaymentSheet(
      BuildContext context, WidgetRef ref) async {
    final customerCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paymentMode = 'Cash';
    final modes = ['Cash', 'UPI', 'Bank Transfer', 'Card', 'Other'];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Record Payment',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: customerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Name or Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '\u20B9 ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                ),
                items: modes
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setSheetState(() => paymentMode = val);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Record Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true &&
        customerCtrl.text.trim().isNotEmpty &&
        amountCtrl.text.isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/credit/payments', data: {
          'customer': customerCtrl.text.trim(),
          'amount': double.tryParse(amountCtrl.text) ?? 0,
          'paymentMode': paymentMode,
        });
        ref.invalidate(creditSummaryProvider);
        ref.invalidate(creditCustomersProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment recorded successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    customerCtrl.dispose();
    amountCtrl.dispose();
  }
}

// ── Customer Card ──────────────────────────────────────────────

class _CreditCustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onTap;
  final VoidCallback onSendReminder;

  const _CreditCustomerCard({
    required this.customer,
    required this.onTap,
    required this.onSendReminder,
  });

  @override
  Widget build(BuildContext context) {
    final name = customer['name'] ?? customer['customerName'] ?? '-';
    final phone = customer['phone'] ?? '-';
    final outstanding =
        (customer['outstanding'] ?? customer['balance'] ?? 0).toDouble();
    final daysSincePayment = customer['daysSinceLastPayment'] ?? customer['daysSince'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    Theme.of(context).colorScheme.errorContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (daysSincePayment != null)
                      Text(
                        '$daysSincePayment days since last payment',
                        style: TextStyle(
                          fontSize: 11,
                          color: (daysSincePayment as int) > 30
                              ? const Color(0xFFDC2626)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupee(outstanding),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton.icon(
                      onPressed: onSendReminder,
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Remind',
                          style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
