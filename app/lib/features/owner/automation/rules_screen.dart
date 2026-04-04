import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'automation_provider.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  IconData _triggerIcon(String? trigger) {
    switch (trigger?.toLowerCase()) {
      case 'low_stock':
        return Icons.inventory_outlined;
      case 'high_wastage':
        return Icons.delete_outline;
      case 'revenue_drop':
        return Icons.trending_down;
      case 'cash_shortage':
        return Icons.money_off;
      case 'expense_threshold':
        return Icons.receipt_long;
      default:
        return Icons.bolt;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(automationRulesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation Rules'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(automationRulesProvider),
        child: rulesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LoadingSkeleton(height: 80),
              ),
            ),
          ),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(automationRulesProvider),
            ),
          ),
          data: (rules) {
            if (rules.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: EmptyState(
                  icon: Icons.bolt_outlined,
                  title: 'No automation rules',
                  subtitle: 'Create rules to automate alerts and actions.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final rule = rules[index];
                final name = rule['name'] ?? 'Untitled';
                final trigger = (rule['triggerType'] ?? rule['trigger'] ?? '').toString();
                final action = (rule['actionType'] ?? rule['action'] ?? '').toString();
                final active = rule['active'] ?? true;
                final timesTriggered = rule['timesTriggered'] ?? 0;
                final id = rule['id']?.toString() ?? '';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_triggerIcon(trigger),
                            size: 28, color: theme.colorScheme.primary),
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
                                  _Badge(
                                      label: trigger.replaceAll('_', ' ').toUpperCase(),
                                      color: const Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_forward,
                                      size: 14, color: const Color(0xFF94A3B8)),
                                  const SizedBox(width: 6),
                                  _Badge(
                                      label: action.replaceAll('_', ' ').toUpperCase(),
                                      color: const Color(0xFF7C3AED)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Triggered $timesTriggered time${timesTriggered == 1 ? '' : 's'}',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: active,
                          onChanged: (val) => toggleRule(ref, id, val),
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
    final thresholdCtrl = TextEditingController();
    final recipientsCtrl = TextEditingController();
    String trigger = 'low_stock';
    String action = 'send_alert';

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
              Text('Create Rule',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Rule Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: trigger,
                decoration: InputDecoration(
                  labelText: 'Trigger',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'low_stock', child: Text('Low Stock')),
                  DropdownMenuItem(value: 'high_wastage', child: Text('High Wastage')),
                  DropdownMenuItem(value: 'revenue_drop', child: Text('Revenue Drop')),
                  DropdownMenuItem(value: 'cash_shortage', child: Text('Cash Shortage')),
                  DropdownMenuItem(
                      value: 'expense_threshold', child: Text('Expense Threshold')),
                ],
                onChanged: (val) => setModalState(() => trigger = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thresholdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Threshold',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: action,
                decoration: InputDecoration(
                  labelText: 'Action',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'send_alert', child: Text('Send Alert')),
                  DropdownMenuItem(value: 'send_whatsapp', child: Text('Send WhatsApp')),
                  DropdownMenuItem(value: 'send_email', child: Text('Send Email')),
                  DropdownMenuItem(value: 'auto_order', child: Text('Auto Order')),
                ],
                onChanged: (val) => setModalState(() => action = val!),
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
                      await createRule(ref, {
                        'name': nameCtrl.text.trim(),
                        'triggerType': trigger,
                        'threshold': double.tryParse(thresholdCtrl.text) ?? 0,
                        'actionType': action,
                        'recipients': recipientsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Create Rule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
