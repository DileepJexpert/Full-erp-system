import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';

// ── Providers ──────────────────────────────────────────────────

final discountRulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/discounts/rules');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final couponsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/discounts/coupons');
  final data = response.data as Map<String, dynamic>;
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────

class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key});

  @override
  ConsumerState<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends ConsumerState<DiscountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  static const _ruleTypes = [
    '% Off',
    'Flat Off',
    'Buy X Get Y',
    'Min Cart',
    'Flash Sale',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discounts & Offers'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Rules'),
            Tab(text: 'Coupons'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildRulesTab(),
          _buildCouponsTab(),
        ],
      ),
    );
  }

  // ── Rules Tab ──

  Widget _buildRulesTab() {
    final rulesAsync = ref.watch(discountRulesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_rule',
        onPressed: () => _showCreateRuleDialog(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(discountRulesProvider),
        child: rulesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LoadingSkeleton(height: 72),
                ),
              ),
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(discountRulesProvider),
          ),
          data: (rules) {
            if (rules.isEmpty) {
              return const EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No discount rules',
                subtitle: 'Create rules to apply discounts automatically.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return _RuleCard(
                  rule: rule,
                  onToggle: (active) => _toggleRule(rule, active),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleRule(Map<String, dynamic> rule, bool active) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/discounts/rules/${rule['id']}', data: {'active': active});
      ref.invalidate(discountRulesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showCreateRuleDialog() async {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final conditionCtrl = TextEditingController();
    String type = _ruleTypes.first;
    DateTime? startDate;
    DateTime? endDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Discount Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rule Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _ruleTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Value (e.g. 10 for 10%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conditionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Conditions (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. min cart 500',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                        child: Text(startDate != null
                            ? formatDate(startDate!)
                            : 'Start Date'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: startDate ?? DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                        child: Text(endDate != null
                            ? formatDate(endDate!)
                            : 'End Date'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/discounts/rules', data: {
          'name': nameCtrl.text.trim(),
          'type': type,
          'value': double.tryParse(valueCtrl.text) ?? 0,
          'conditions': conditionCtrl.text.trim(),
          if (startDate != null) 'startDate': formatDateApi(startDate!),
          if (endDate != null) 'endDate': formatDateApi(endDate!),
          'active': true,
        });
        ref.invalidate(discountRulesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Discount rule created'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }

    nameCtrl.dispose();
    valueCtrl.dispose();
    conditionCtrl.dispose();
  }

  // ── Coupons Tab ──

  Widget _buildCouponsTab() {
    final couponsAsync = ref.watch(couponsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_coupon',
        onPressed: () => _showCreateCouponDialog(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(couponsProvider),
        child: couponsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LoadingSkeleton(height: 72),
                ),
              ),
            ),
          ),
          error: (err, _) => ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(couponsProvider),
          ),
          data: (coupons) {
            if (coupons.isEmpty) {
              return const EmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'No coupons yet',
                subtitle: 'Create coupons for customers to redeem.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coupons.length,
              itemBuilder: (context, index) => _CouponCard(
                  coupon: coupons[index]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateCouponDialog() async {
    final codeCtrl = TextEditingController();
    final ruleCtrl = TextEditingController();
    final maxRedemptionsCtrl = TextEditingController();
    DateTime? expiry;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Coupon Code',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ruleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Linked Rule Name or ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxRedemptionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Max Redemptions',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => expiry = picked);
                    }
                  },
                  child: Text(
                      expiry != null ? 'Expires: ${formatDate(expiry!)}' : 'Set Expiry Date'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && codeCtrl.text.trim().isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/discounts/coupons', data: {
          'code': codeCtrl.text.trim().toUpperCase(),
          'linkedRule': ruleCtrl.text.trim(),
          'maxRedemptions': int.tryParse(maxRedemptionsCtrl.text) ?? 0,
          if (expiry != null) 'expiry': formatDateApi(expiry!),
        });
        ref.invalidate(couponsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Coupon created'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }

    codeCtrl.dispose();
    ruleCtrl.dispose();
    maxRedemptionsCtrl.dispose();
  }
}

// ── Rule Card ──────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final ValueChanged<bool> onToggle;

  const _RuleCard({required this.rule, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final name = rule['name'] ?? '-';
    final type = rule['type'] ?? '-';
    final value = rule['value'] ?? 0;
    final active = rule['active'] == true;
    final startDate = rule['startDate'] != null
        ? DateTime.tryParse(rule['startDate'])
        : null;
    final endDate =
        rule['endDate'] != null ? DateTime.tryParse(rule['endDate']) : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
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
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_offer,
                  color: Color(0xFF7C3AED), size: 22),
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
                    '$type: $value',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (startDate != null && endDate != null)
                    Text(
                      '${formatDate(startDate)} - ${formatDate(endDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: active,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coupon Card ────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;

  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final code = coupon['code'] ?? '-';
    final linkedRule = coupon['linkedRule'] ?? coupon['ruleName'] ?? '-';
    final redemptions = coupon['redemptions'] ?? 0;
    final maxRedemptions = coupon['maxRedemptions'] ?? 0;
    final expiry =
        coupon['expiry'] != null ? DateTime.tryParse(coupon['expiry']) : null;
    final isExpired =
        expiry != null && expiry.isBefore(DateTime.now());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
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
                color: (isExpired ? Colors.grey : const Color(0xFF2563EB))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.confirmation_number,
                color: isExpired ? Colors.grey : const Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rule: $linkedRule',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Used: $redemptions${maxRedemptions > 0 ? '/$maxRedemptions' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (expiry != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          isExpired
                              ? 'Expired'
                              : 'Expires: ${formatDate(expiry)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isExpired
                                ? const Color(0xFFDC2626)
                                : Theme.of(context)
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
          ],
        ),
      ),
    );
  }
}
