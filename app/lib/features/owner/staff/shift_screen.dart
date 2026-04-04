import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'shift_provider.dart';

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(currentWeekStartProvider);
    final scheduleAsync = ref.watch(shiftScheduleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Schedule'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref
                      .read(currentWeekStartProvider.notifier)
                      .state = weekStart.subtract(const Duration(days: 7)),
                ),
                Text(
                  '${formatDate(weekStart)} - ${formatDate(weekStart.add(const Duration(days: 6)))}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => ref
                      .read(currentWeekStartProvider.notifier)
                      .state = weekStart.add(const Duration(days: 7)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            scheduleAsync.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LoadingSkeleton(height: 60),
                  ),
                ),
              ),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(shiftScheduleProvider),
              ),
              data: (data) {
                final locations = (data['locations'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                final shifts = (data['shifts'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];

                if (locations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No locations found',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF94A3B8))),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerLow,
                    ),
                    border: TableBorder.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    columns: [
                      const DataColumn(label: Text('Location')),
                      ..._dayLabels.map((d) => DataColumn(label: Text(d))),
                    ],
                    rows: locations.map((loc) {
                      final locId = loc['id']?.toString() ?? '';
                      final locName = loc['name'] ?? '-';

                      return DataRow(
                        cells: [
                          DataCell(Text(locName,
                              style: const TextStyle(fontWeight: FontWeight.w500))),
                          ...List.generate(7, (dayIndex) {
                            final dayDate =
                                weekStart.add(Duration(days: dayIndex));
                            final dayStr = formatDateApi(dayDate);

                            // Find shifts for this location and day
                            final dayShifts = shifts.where((s) =>
                                s['locationId']?.toString() == locId &&
                                (s['date']?.toString() ?? '').startsWith(dayStr));

                            final names = dayShifts
                                .map((s) =>
                                    s['operatorName'] ??
                                    s['operator']?['name'] ??
                                    '?')
                                .toList();

                            return DataCell(
                              InkWell(
                                onTap: () =>
                                    _showAssignDialog(context, ref, locId, dayStr),
                                child: names.isEmpty
                                    ? const Icon(Icons.add_circle_outline,
                                        size: 18, color: Color(0xFF94A3B8))
                                    : Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: names
                                            .map((n) => Chip(
                                                  label: Text(n.toString(),
                                                      style: const TextStyle(
                                                          fontSize: 11)),
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                ))
                                            .toList(),
                                      ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(
      BuildContext context, WidgetRef ref, String locationId, String date) {
    final operatorCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Operator'),
        content: TextField(
          controller: operatorCtrl,
          decoration: InputDecoration(
            labelText: 'Operator ID',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (operatorCtrl.text.trim().isEmpty) return;
              try {
                await assignShift(ref, {
                  'locationId': locationId,
                  'date': date,
                  'operatorId': operatorCtrl.text.trim(),
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
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}
