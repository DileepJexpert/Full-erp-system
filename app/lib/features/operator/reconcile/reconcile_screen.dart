import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import 'reconcile_provider.dart';

class ReconcileScreen extends ConsumerWidget {
  const ReconcileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reconcileProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(reconcileProvider.notifier).loadDispatch(),
      );
    }

    if (state.submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72, color: Color(0xFF16A34A)),
              const SizedBox(height: 16),
              Text(
                'Reconciliation Submitted',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your reconciliation for today has been submitted successfully.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(reconcileProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Start Over'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Dispatch Today',
        subtitle: 'There are no dispatched items to reconcile today.',
        actionLabel: 'Refresh',
        onAction: () => ref.read(reconcileProvider.notifier).loadDispatch(),
      );
    }

    return Column(
      children: [
        // Summary card
        _SummaryCard(state: state),

        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _ReconcileItemCard(
                item: state.items[index],
                index: index,
              );
            },
          ),
        ),

        // Submit bar
        _SubmitBar(state: state),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ReconcileState state;

  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryStat(
              label: 'Items',
              value: '${state.itemCount}',
              color: const Color(0xFF2563EB),
            ),
            _divider(),
            _SummaryStat(
              label: 'Dispatched',
              value: '${state.totalDispatched}',
              color: const Color(0xFF64748B),
            ),
            _divider(),
            _SummaryStat(
              label: 'Sold',
              value: '${state.totalSold}',
              color: const Color(0xFF16A34A),
            ),
            _divider(),
            _SummaryStat(
              label: 'Wasted',
              value: '${state.totalWasted}',
              color: state.totalWasted > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE2E8F0),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF94A3B8),
                ),
          ),
        ],
      ),
    );
  }
}

class _ReconcileItemCard extends ConsumerStatefulWidget {
  final DispatchItem item;
  final int index;

  const _ReconcileItemCard({required this.item, required this.index});

  @override
  ConsumerState<_ReconcileItemCard> createState() =>
      _ReconcileItemCardState();
}

class _ReconcileItemCardState extends ConsumerState<_ReconcileItemCard> {
  late final TextEditingController _soldController;
  late final TextEditingController _returnedController;

  @override
  void initState() {
    super.initState();
    _soldController =
        TextEditingController(text: widget.item.sold.toString());
    _returnedController =
        TextEditingController(text: widget.item.returned.toString());
  }

  @override
  void didUpdateWidget(covariant _ReconcileItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.sold != widget.item.sold) {
      final text = widget.item.sold.toString();
      if (_soldController.text != text) {
        _soldController.text = text;
      }
    }
    if (oldWidget.item.returned != widget.item.returned) {
      final text = widget.item.returned.toString();
      if (_returnedController.text != text) {
        _returnedController.text = text;
      }
    }
  }

  @override
  void dispose() {
    _soldController.dispose();
    _returnedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final wasted = item.wasted;
    final wastedColor =
        wasted > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: item name + dispatched
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.itemName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Dispatched: ${item.dispatched} ${item.unit}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Input row: Sold / Returned
            Row(
              children: [
                Expanded(
                  child: _QuantityField(
                    label: 'Sold',
                    controller: _soldController,
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      ref
                          .read(reconcileProvider.notifier)
                          .updateSold(widget.index, parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuantityField(
                    label: 'Returned',
                    controller: _returnedController,
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      ref
                          .read(reconcileProvider.notifier)
                          .updateReturned(widget.index, parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Wasted display
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wasted',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF94A3B8),
                                ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: wasted > 0
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: wasted > 0
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          '$wasted',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: wastedColor,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _QuantityField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF94A3B8),
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitBar extends ConsumerWidget {
  final ReconcileState state;

  const _SubmitBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFDC2626),
                      ),
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => _handleSubmit(context, ref),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Reconciliation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Reconciliation?'),
        content: Text(
          'Total sold: ${state.totalSold}, '
          'Total returned: ${state.totalReturned}, '
          'Total wasted: ${state.totalWasted}.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(reconcileProvider.notifier).submit();
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconciliation submitted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
