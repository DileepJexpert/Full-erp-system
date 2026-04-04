import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';
import 'budget_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  String? _selectedLocation;
  bool _showForm = false;

  final _revenueCtrl = TextEditingController();
  final _cogsCtrl = TextEditingController();
  final _expenseCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _profitCtrl = TextEditingController();

  @override
  void dispose() {
    _revenueCtrl.dispose();
    _cogsCtrl.dispose();
    _expenseCtrl.dispose();
    _salaryCtrl.dispose();
    _profitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedBudgetMonthProvider);
    final varianceAsync = ref.watch(budgetVarianceProvider(month));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_showForm ? Icons.dashboard : Icons.edit_note),
            onPressed: () => setState(() => _showForm = !_showForm),
            tooltip: _showForm ? 'View dashboard' : 'Set targets',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(budgetVarianceProvider(month));
          ref.invalidate(budgetsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month selector
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(ref, -1),
                  ),
                  Text(
                    _formatMonth(month),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(ref, 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Location selector
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Locations')),
                ],
                onChanged: (val) => setState(() => _selectedLocation = val),
              ),
              const SizedBox(height: 24),
              if (_showForm) _buildForm(context) else _buildDashboard(varianceAsync, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set Budget Targets',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildField(_revenueCtrl, 'Revenue Target'),
            const SizedBox(height: 12),
            _buildField(_cogsCtrl, 'COGS Target'),
            const SizedBox(height: 12),
            _buildField(_expenseCtrl, 'Expenses Target'),
            const SizedBox(height: 12),
            _buildField(_salaryCtrl, 'Salary Target'),
            const SizedBox(height: 12),
            _buildField(_profitCtrl, 'Profit Target'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveBudget,
                child: const Text('Save Budget'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\u20B9 ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
  }

  Future<void> _saveBudget() async {
    final month = ref.read(selectedBudgetMonthProvider);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/budgets', data: {
        'month': month,
        'locationId': _selectedLocation,
        'revenue': double.tryParse(_revenueCtrl.text) ?? 0,
        'cogs': double.tryParse(_cogsCtrl.text) ?? 0,
        'expenses': double.tryParse(_expenseCtrl.text) ?? 0,
        'salary': double.tryParse(_salaryCtrl.text) ?? 0,
        'profit': double.tryParse(_profitCtrl.text) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget saved')),
        );
        setState(() => _showForm = false);
        ref.invalidate(budgetVarianceProvider(month));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildDashboard(
      AsyncValue<Map<String, dynamic>> varianceAsync, ThemeData theme) {
    return varianceAsync.when(
      loading: () => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: List.generate(5, (_) => SizedBox(width: 300, child: LoadingSkeleton.card())),
      ),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () {
          final month = ref.read(selectedBudgetMonthProvider);
          ref.invalidate(budgetVarianceProvider(month));
        },
      ),
      data: (data) {
        final items = <_BudgetItem>[
          _BudgetItem('Revenue', data['revenueTarget'], data['revenueActual'], true),
          _BudgetItem('COGS', data['cogsTarget'], data['cogsActual'], false),
          _BudgetItem('Expenses', data['expensesTarget'], data['expensesActual'], false),
          _BudgetItem('Salary', data['salaryTarget'], data['salaryActual'], false),
          _BudgetItem('Profit', data['profitTarget'], data['profitActual'], true),
        ];

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map((item) => SizedBox(
                    width: 300,
                    child: _VarianceCard(item: item),
                  ))
              .toList(),
        );
      },
    );
  }

  void _changeMonth(WidgetRef ref, int delta) {
    final current = ref.read(selectedBudgetMonthProvider);
    final parts = current.split('-');
    var year = int.parse(parts[0]);
    var monthNum = int.parse(parts[1]) + delta;
    if (monthNum > 12) {
      monthNum = 1;
      year++;
    } else if (monthNum < 1) {
      monthNum = 12;
      year--;
    }
    ref.read(selectedBudgetMonthProvider.notifier).state =
        '$year-${monthNum.toString().padLeft(2, '0')}';
  }

  String _formatMonth(String month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final parts = month.split('-');
    return '${months[int.parse(parts[1])]} ${parts[0]}';
  }
}

class _BudgetItem {
  final String label;
  final dynamic target;
  final dynamic actual;
  final bool higherIsBetter; // true for revenue/profit, false for expenses

  _BudgetItem(this.label, this.target, this.actual, this.higherIsBetter);

  double get targetVal => (target ?? 0).toDouble();
  double get actualVal => (actual ?? 0).toDouble();
  double get variance => actualVal - targetVal;
  double get variancePercent =>
      targetVal != 0 ? (variance / targetVal * 100) : 0;

  bool get isGood => higherIsBetter ? actualVal >= targetVal : actualVal <= targetVal;
}

class _VarianceCard extends StatelessWidget {
  final _BudgetItem item;

  const _VarianceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goodColor = const Color(0xFF16A34A);
    final badColor = const Color(0xFFDC2626);
    final statusColor = item.isGood ? goodColor : badColor;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: const Color(0xFF64748B))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Target', style: theme.textTheme.labelSmall),
                    Text(formatRupee(item.targetVal),
                        style: theme.textTheme.titleSmall),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Actual', style: theme.textTheme.labelSmall),
                    Text(formatRupee(item.actualVal),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isGood ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${formatRupee(item.variance.abs())} (${item.variancePercent.abs().toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
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
