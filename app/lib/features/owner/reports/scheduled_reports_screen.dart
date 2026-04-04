import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';

final scheduledReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/reports/scheduled');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class ScheduledReportsScreen extends ConsumerWidget {
  const ScheduledReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(scheduledReportsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Reports'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(scheduledReportsProvider),
        child: reportsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LoadingSkeleton.card(),
              ),
            ),
          ),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(scheduledReportsProvider),
            ),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: EmptyState(
                  icon: Icons.schedule_send_outlined,
                  title: 'No scheduled reports',
                  subtitle: 'Set up automated report delivery.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final report = reports[index];
                final name = report['name'] ?? 'Report';
                final type = (report['type'] ?? report['reportType'] ?? '').toString();
                final frequency = (report['frequency'] ?? '').toString();
                final channel = (report['channel'] ?? '').toString();
                final active = report['active'] ?? true;
                final lastSent = report['lastSent'] != null
                    ? DateTime.tryParse(report['lastSent'].toString())
                    : null;
                final id = report['id']?.toString() ?? '';

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
                    child: Row(
                      children: [
                        Icon(
                          channel.toLowerCase() == 'whatsapp'
                              ? Icons.chat
                              : Icons.email_outlined,
                          size: 28,
                          color: channel.toLowerCase() == 'whatsapp'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _Chip(label: type.replaceAll('_', ' ')),
                                  const SizedBox(width: 6),
                                  _Chip(label: frequency),
                                ],
                              ),
                              if (lastSent != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Last sent: ${formatDate(lastSent)}',
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Switch(
                          value: active,
                          onChanged: (val) async {
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.put('/reports/scheduled/$id',
                                  data: {'active': val});
                              ref.invalidate(scheduledReportsProvider);
                            } catch (_) {}
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final recipientsCtrl = TextEditingController();
    String reportType = 'daily_sales';
    String frequency = 'daily';
    String channel = 'whatsapp';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Scheduled Report',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Report Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reportType,
                decoration: InputDecoration(
                  labelText: 'Report Type',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'daily_sales', child: Text('Daily Sales')),
                  DropdownMenuItem(value: 'weekly_summary', child: Text('Weekly Summary')),
                  DropdownMenuItem(value: 'monthly_pnl', child: Text('Monthly P&L')),
                  DropdownMenuItem(value: 'inventory_report', child: Text('Inventory')),
                  DropdownMenuItem(value: 'staff_attendance', child: Text('Staff Attendance')),
                ],
                onChanged: (val) => setModalState(() => reportType = val!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: frequency,
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (val) => setModalState(() => frequency = val!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: channel,
                decoration: InputDecoration(
                  labelText: 'Channel',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                ],
                onChanged: (val) => setModalState(() => channel = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: recipientsCtrl,
                decoration: InputDecoration(
                  labelText: 'Recipients (comma separated)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      final api = ref.read(apiClientProvider);
                      await api.post('/reports/scheduled', data: {
                        'name': nameCtrl.text.trim(),
                        'reportType': reportType,
                        'frequency': frequency,
                        'channel': channel,
                        'recipients': recipientsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      });
                      ref.invalidate(scheduledReportsProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Create Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
