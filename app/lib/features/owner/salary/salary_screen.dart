import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'salary_provider.dart';

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(monthlySalaryProvider);
    final selectedMonth = ref.watch(salaryMonthProvider);
    final selectedYear = ref.watch(salaryYearProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Salaries'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(monthlySalaryProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month/Year selector
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          if (selectedMonth == 1) {
                            ref.read(salaryMonthProvider.notifier).state = 12;
                            ref.read(salaryYearProvider.notifier).state =
                                selectedYear - 1;
                          } else {
                            ref.read(salaryMonthProvider.notifier).state =
                                selectedMonth - 1;
                          }
                        },
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DropdownButton<int>(
                              value: selectedMonth,
                              underline: const SizedBox.shrink(),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_months[i]),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(salaryMonthProvider.notifier)
                                      .state = val;
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: selectedYear,
                              underline: const SizedBox.shrink(),
                              items: List.generate(
                                5,
                                (i) {
                                  final y = now.year - i;
                                  return DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  );
                                },
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  ref
                                      .read(salaryYearProvider.notifier)
                                      .state = val;
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          if (selectedMonth == 12) {
                            ref.read(salaryMonthProvider.notifier).state = 1;
                            ref.read(salaryYearProvider.notifier).state =
                                selectedYear + 1;
                          } else {
                            ref.read(salaryMonthProvider.notifier).state =
                                selectedMonth + 1;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Salary table
              salaryAsync.when(
                loading: () => Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton(height: 52),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(monthlySalaryProvider),
                ),
                data: (data) {
                  final staff = (data['salaries'] as List?)
                          ?.cast<Map<String, dynamic>>() ??
                      [];

                  if (staff.isEmpty) {
                    return const EmptyState(
                      icon: Icons.payments_outlined,
                      title: 'No salary data',
                      subtitle:
                          'Salary records for this month will appear here.',
                    );
                  }

                  // Calculate totals
                  double totalBase = 0;
                  double totalLossDed = 0;
                  double totalCashShort = 0;
                  double totalAdvances = 0;
                  double totalBonus = 0;
                  double totalNet = 0;

                  for (final s in staff) {
                    totalBase += (s['baseSalary'] ?? 0).toDouble();
                    totalLossDed +=
                        (s['lossDed'] ?? s['lossDeduction'] ?? 0).toDouble();
                    totalCashShort +=
                        (s['cashShort'] ?? s['cashShortage'] ?? 0).toDouble();
                    totalAdvances += (s['advances'] ?? 0).toDouble();
                    totalBonus += (s['bonus'] ?? 0).toDouble();
                    totalNet += (s['netSalary'] ?? 0).toDouble();
                  }

                  return Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.5),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                        ),
                        columns: const [
                          DataColumn(label: Text('Staff')),
                          DataColumn(label: Text('Base'), numeric: true),
                          DataColumn(
                              label: Text('Loss Ded.'), numeric: true),
                          DataColumn(
                              label: Text('Cash Short'), numeric: true),
                          DataColumn(
                              label: Text('Advances'), numeric: true),
                          DataColumn(label: Text('Bonus'), numeric: true),
                          DataColumn(
                              label: Text('Net Salary'), numeric: true),
                        ],
                        rows: [
                          ...staff.map((s) {
                            final base =
                                (s['baseSalary'] ?? 0).toDouble();
                            final lossDed =
                                (s['lossDed'] ?? s['lossDeduction'] ?? 0)
                                    .toDouble();
                            final cashShort =
                                (s['cashShort'] ?? s['cashShortage'] ?? 0)
                                    .toDouble();
                            final advances =
                                (s['advances'] ?? 0).toDouble();
                            final bonus = (s['bonus'] ?? 0).toDouble();
                            final net = (s['netSalary'] ?? 0).toDouble();

                            return DataRow(cells: [
                              DataCell(Text(
                                s['staffName'] ??
                                    s['staff']?['name'] ??
                                    '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              )),
                              DataCell(Text(formatRupee(base))),
                              DataCell(Text(
                                formatRupee(lossDed),
                                style: TextStyle(
                                  color: lossDed > 0
                                      ? const Color(0xFFDC2626)
                                      : null,
                                ),
                              )),
                              DataCell(Text(
                                formatRupee(cashShort),
                                style: TextStyle(
                                  color: cashShort > 0
                                      ? const Color(0xFFDC2626)
                                      : null,
                                ),
                              )),
                              DataCell(Text(formatRupee(advances))),
                              DataCell(Text(
                                formatRupee(bonus),
                                style: TextStyle(
                                  color: bonus > 0
                                      ? const Color(0xFF16A34A)
                                      : null,
                                ),
                              )),
                              DataCell(Text(
                                formatRupee(net),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              )),
                            ]);
                          }),
                          // Summary row
                          DataRow(
                            color: WidgetStateProperty.all(
                              Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.3),
                            ),
                            cells: [
                              const DataCell(Text(
                                'TOTAL',
                                style:
                                    TextStyle(fontWeight: FontWeight.w800),
                              )),
                              DataCell(Text(
                                formatRupee(totalBase),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              )),
                              DataCell(Text(
                                formatRupee(totalLossDed),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626)),
                              )),
                              DataCell(Text(
                                formatRupee(totalCashShort),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626)),
                              )),
                              DataCell(Text(
                                formatRupee(totalAdvances),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              )),
                              DataCell(Text(
                                formatRupee(totalBonus),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A)),
                              )),
                              DataCell(Text(
                                formatRupee(totalNet),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
