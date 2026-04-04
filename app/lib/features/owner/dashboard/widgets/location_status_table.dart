import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/formatters/currency.dart';
import '../dashboard_provider.dart';

class LocationStatusTable extends ConsumerWidget {
  const LocationStatusTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(locationStatsProvider);
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
      data: (stats) {
        if (stats.isEmpty) return const Text('No location data');
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Revenue'), numeric: true),
                DataColumn(label: Text('Loss'), numeric: true),
                DataColumn(label: Text('Bills'), numeric: true),
              ],
              rows: stats.map((s) => DataRow(cells: [
                DataCell(Text(s['locationName'] ?? '')),
                DataCell(Text(formatRupee((s['totalRevenue'] ?? 0).toDouble()))),
                DataCell(Text(formatRupee((s['totalLoss'] ?? 0).toDouble()), style: const TextStyle(color: Color(0xFFDC2626)))),
                DataCell(Text('${s['billCount'] ?? 0}')),
              ])).toList(),
            ),
          ),
        );
      },
    );
  }
}
