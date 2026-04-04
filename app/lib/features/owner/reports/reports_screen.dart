import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import 'reports_provider.dart';

class _ReportType {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReportType({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _reportTypes = [
  _ReportType(
    key: 'daily-sales',
    title: 'Daily Sales Summary',
    subtitle: 'Revenue, bill count, and payment breakdowns',
    icon: Icons.point_of_sale,
    color: Color(0xFF16A34A),
  ),
  _ReportType(
    key: 'monthly-pnl',
    title: 'Monthly P&L',
    subtitle: 'Profit and loss statement by month',
    icon: Icons.analytics,
    color: Color(0xFF2563EB),
  ),
  _ReportType(
    key: 'staff-attendance',
    title: 'Staff Attendance',
    subtitle: 'Attendance records and punctuality',
    icon: Icons.people,
    color: Color(0xFF7C3AED),
  ),
  _ReportType(
    key: 'wastage-analysis',
    title: 'Wastage Analysis',
    subtitle: 'Wastage trends and cost impact',
    icon: Icons.delete_sweep,
    color: Color(0xFFDC2626),
  ),
  _ReportType(
    key: 'cash-collection',
    title: 'Cash Collection Summary',
    subtitle: 'Cash deposits, shortages, and reconciliation',
    icon: Icons.account_balance_wallet,
    color: Color(0xFFF59E0B),
  ),
];

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate and view business reports',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _reportTypes.map((type) {
                  final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
                  return SizedBox(
                    width: cardWidth,
                    child: _ReportTypeCard(reportType: type),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  final _ReportType reportType;

  const _ReportTypeCard({required this.reportType});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ReportDetailScreen(
                reportKey: reportType.key,
                reportTitle: reportType.title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: reportType.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(reportType.icon, color: reportType.color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                reportType.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                reportType.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'View report',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDetailScreen extends ConsumerWidget {
  final String reportKey;
  final String reportTitle;

  const _ReportDetailScreen({required this.reportKey, required this.reportTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportDateRangeProvider);
    final request = ReportRequest(type: reportKey, dateRange: dateRange);
    final reportAsync = ref.watch(reportProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: Text(reportTitle),
        actions: [
          TextButton.icon(
            onPressed: () => _selectDateRange(context, ref),
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              '${formatDate(dateRange.start)} - ${formatDate(dateRange.end)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reportProvider(request)),
        child: reportAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: List.generate(
                5,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton.card(),
                ),
              ),
            ),
          ),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(reportProvider(request)),
              ),
            ),
          ),
          data: (report) {
            if (report.rows.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: EmptyState(
                    icon: Icons.table_chart_outlined,
                    title: 'No data available',
                    subtitle: 'Try adjusting the date range.',
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.summary != null && report.summary!.isNotEmpty) ...[
                    _SummarySection(summary: report.summary!),
                    const SizedBox(height: 24),
                  ],
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: report.columns
                            .map((col) => DataColumn(
                                  label: Text(
                                    col,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ))
                            .toList(),
                        rows: report.rows.map((row) {
                          return DataRow(
                            cells: report.columns.map((col) {
                              final value = row[col];
                              return DataCell(Text(_formatCellValue(value)));
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      if (value.toDouble() == value.roundToDouble() && value.abs() < 1000000) {
        return value.toStringAsFixed(0);
      }
      return formatRupeeDecimal(value.toDouble());
    }
    return value.toString();
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(reportDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: current,
    );
    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = picked;
    }
  }
}

class _SummarySection extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: summary.entries.map((entry) {
        final displayValue = entry.value is num
            ? formatRupee((entry.value as num).toDouble())
            : entry.value.toString();
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _humanizeKey(entry.key),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  displayValue,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _humanizeKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
