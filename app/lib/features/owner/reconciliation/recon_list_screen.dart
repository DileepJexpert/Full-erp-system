import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'recon_provider.dart';

class ReconListScreen extends ConsumerWidget {
  const ReconListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reconAsync = ref.watch(reconListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reconListProvider),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reconciliations',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Review dispatch vs sales reconciliation',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            reconAsync.when(
              loading: () => Column(
                children: List.generate(
                    4,
                    (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LoadingSkeleton(height: 80),
                        )),
              ),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(reconListProvider),
              ),
              data: (recons) {
                if (recons.isEmpty) {
                  return const EmptyState(
                    icon: Icons.fact_check,
                    title: 'No reconciliations yet',
                    subtitle:
                        'Reconciliations appear after dispatches are completed',
                  );
                }
                return Column(
                  children: recons.map((r) {
                    final date = DateTime.tryParse(r['date'] ?? '');
                    final totalLoss = (r['totalLoss'] ?? 0).toDouble();
                    final locationName =
                        r['location']?['name'] ?? r['locationName'] ?? '-';
                    final status = r['status'] ?? 'PENDING';
                    final id = r['id'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.go('/reconcile/$id'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: totalLoss > 0
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  totalLoss > 0
                                      ? Icons.trending_down
                                      : Icons.check_circle,
                                  color: totalLoss > 0
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      date != null ? formatDate(date) : '-',
                                      style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    totalLoss > 0
                                        ? 'Loss: ${formatRupee(totalLoss)}'
                                        : 'No Loss',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: totalLoss > 0
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Text(
                                      status,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right,
                                  color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
