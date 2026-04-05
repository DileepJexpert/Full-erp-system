import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final creditRemindersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/reminders/credit');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final invoiceRemindersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/reminders/invoices');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(creditRemindersProvider);
    final invoiceAsync = ref.watch(invoiceRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Reminders'),
        actions: [
          TextButton.icon(
            onPressed: () => _sendAllReminders(context, ref),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send All'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(creditRemindersProvider);
          ref.invalidate(invoiceRemindersProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Run Reminder Check button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _runReminderCheck(context, ref),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Run Reminder Check'),
                ),
              ),
              const SizedBox(height: 20),
              // ── Credit Reminders ──
              Text(
                'Credit Reminders',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              creditAsync.when(
                loading: () => Column(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton.card(),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(creditRemindersProvider),
                ),
                data: (reminders) {
                  if (reminders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'No overdue credit payments',
                        subtitle: 'All customers are up to date.',
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reminders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final r = reminders[index];
                      return _CreditReminderCard(
                        reminder: r,
                        onSend: () => _sendCreditReminder(context, ref, r),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              // ── Invoice Reminders ──
              Text(
                'Invoice Reminders',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              invoiceAsync.when(
                loading: () => Column(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton.card(),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(invoiceRemindersProvider),
                ),
                data: (reminders) {
                  if (reminders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No upcoming invoices',
                        subtitle: 'No recurring invoices are due soon.',
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reminders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final r = reminders[index];
                      return _InvoiceReminderCard(
                        reminder: r,
                        onSend: () => _sendInvoiceReminder(context, ref, r),
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

  Future<void> _sendAllReminders(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/reminders/send-all');
      ref.invalidate(creditRemindersProvider);
      ref.invalidate(invoiceRemindersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All reminders sent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _runReminderCheck(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/reminders/check');
      ref.invalidate(creditRemindersProvider);
      ref.invalidate(invoiceRemindersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder check completed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _sendCreditReminder(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    try {
      final api = ref.read(apiClientProvider);
      final id = r['id'] ?? r['customerId'] ?? '';
      await api.post('/reminders/credit/$id/send');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _sendInvoiceReminder(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    try {
      final api = ref.read(apiClientProvider);
      final id = r['id'] ?? r['invoiceId'] ?? '';
      await api.post('/reminders/invoices/$id/send');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

// ── Credit Reminder Card ───────────────────────────────────────

class _CreditReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;
  final VoidCallback onSend;

  const _CreditReminderCard({required this.reminder, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final name = reminder['customerName'] ?? reminder['name'] ?? '-';
    final amount =
        (reminder['amount'] ?? reminder['outstanding'] ?? 0).toDouble();
    final daysOverdue =
        reminder['daysOverdue'] ?? reminder['daysSince'] ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline,
                  color: Color(0xFFDC2626), size: 22),
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
                  Row(
                    children: [
                      Text(
                        formatRupee(amount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAB308).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$daysOverdue days overdue',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFEAB308),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send, size: 14),
                label: const Text('Send', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invoice Reminder Card ──────────────────────────────────────

class _InvoiceReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;
  final VoidCallback onSend;

  const _InvoiceReminderCard({required this.reminder, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final invoiceNum =
        reminder['invoiceNumber'] ?? reminder['id'] ?? '-';
    final customer =
        reminder['customerName'] ?? reminder['customer'] ?? '-';
    final amount = (reminder['amount'] ?? 0).toDouble();
    final dueDate = reminder['dueDate'] != null
        ? DateTime.tryParse(reminder['dueDate'])
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long,
                  color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #$invoiceNum',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        formatRupee(amount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (dueDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Due: ${formatDate(dueDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send, size: 14),
                label: const Text('Send', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
