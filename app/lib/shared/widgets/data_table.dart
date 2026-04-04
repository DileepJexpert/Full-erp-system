import 'package:flutter/material.dart';

class AppDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool showPagination;
  final int? currentPage;
  final int? totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.showPagination = false,
    this.currentPage,
    this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: columns,
            rows: rows,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columnSpacing: 24,
          ),
        ),
        if (showPagination && currentPage != null && totalPages != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Page $currentPage of $totalPages',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: currentPage! > 1 ? onPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 20,
                ),
                IconButton(
                  onPressed: currentPage! < totalPages! ? onNext : null,
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 20,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
