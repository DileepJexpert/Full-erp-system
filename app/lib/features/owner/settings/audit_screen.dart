import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';

final _auditPageProvider = StateProvider<int>((ref) => 1);
final _auditEntityFilterProvider = StateProvider<String?>((ref) => null);

final auditLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final page = ref.watch(_auditPageProvider);
  final entity = ref.watch(_auditEntityFilterProvider);

  final params = <String, dynamic>{'page': page, 'limit': 50};
  if (entity != null) params['entity'] = entity;

  final response = await api.get('/audit-logs', queryParameters: params);
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String _search = '';
  final _expandedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);
    final entityFilter = ref.watch(_auditEntityFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(auditLogsProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and filters
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search logs...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _search = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: entityFilter,
                      decoration: InputDecoration(
                        labelText: 'Entity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'bill', child: Text('Bill')),
                        DropdownMenuItem(value: 'item', child: Text('Item')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(value: 'location', child: Text('Location')),
                        DropdownMenuItem(value: 'dispatch', child: Text('Dispatch')),
                      ],
                      onChanged: (val) =>
                          ref.read(_auditEntityFilterProvider.notifier).state = val,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              logsAsync.when(
                loading: () => Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LoadingSkeleton(height: 56),
                    ),
                  ),
                ),
                error: (err, _) => ErrorView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(auditLogsProvider),
                ),
                data: (logs) {
                  var filtered = logs;
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    filtered = filtered
                        .where((l) =>
                            (l['entityType'] ?? '').toString().toLowerCase().contains(q) ||
                            (l['action'] ?? '').toString().toLowerCase().contains(q) ||
                            (l['userName'] ?? l['user']?['name'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(q))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No audit logs found',
                      subtitle: 'Audit trail entries will appear here.',
                    );
                  }

                  return Column(
                    children: [
                      Card(
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.5),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                          itemBuilder: (context, index) {
                            final log = filtered[index];
                            return _AuditRow(
                              log: log,
                              isExpanded: _expandedIds
                                  .contains(log['id']?.toString() ?? '$index'),
                              onToggle: () {
                                setState(() {
                                  final key =
                                      log['id']?.toString() ?? '$index';
                                  if (_expandedIds.contains(key)) {
                                    _expandedIds.remove(key);
                                  } else {
                                    _expandedIds.add(key);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            final page = ref.read(_auditPageProvider);
                            ref.read(_auditPageProvider.notifier).state =
                                page + 1;
                          },
                          child: const Text('Load More'),
                        ),
                      ),
                    ],
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

class _AuditRow extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _AuditRow({
    required this.log,
    required this.isExpanded,
    required this.onToggle,
  });

  Color _actionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return const Color(0xFF16A34A);
      case 'UPDATE':
        return const Color(0xFF2563EB);
      case 'DELETE':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entityType = (log['entityType'] ?? '').toString();
    final action = (log['action'] ?? '').toString();
    final userName = log['userName'] ?? log['user']?['name'] ?? '-';
    final timestamp = DateTime.tryParse((log['createdAt'] ?? log['timestamp'] ?? '').toString());
    final oldValues = log['oldValues'] ?? log['old'];
    final newValues = log['newValues'] ?? log['new'];

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _actionColor(action).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    action.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _actionColor(action),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entityType,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  userName.toString(),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Text(
                  timestamp != null ? formatDateTime(timestamp) : '-',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: const Color(0xFF94A3B8)),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
            if (isExpanded && (oldValues != null || newValues != null)) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (oldValues != null) ...[
                      Text('Old values:',
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626))),
                      const SizedBox(height: 4),
                      Text(oldValues.toString(),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace', fontSize: 12)),
                      const SizedBox(height: 8),
                    ],
                    if (newValues != null) ...[
                      Text('New values:',
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A))),
                      const SizedBox(height: 4),
                      Text(newValues.toString(),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
