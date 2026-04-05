import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';

final feedbackDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/feedback/dashboard');
  return response.data as Map<String, dynamic>;
});

class FeedbackDashboardScreen extends ConsumerWidget {
  const FeedbackDashboardScreen({super.key});

  Color _npsColor(double nps) {
    if (nps >= 50) return const Color(0xFF16A34A);
    if (nps >= 0) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(feedbackDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Dashboard'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedbackDashboardProvider),
        child: dashboardAsync.when(
          loading: () => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                4,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton.card(),
                ),
              ),
            ),
          ),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(feedbackDashboardProvider),
            ),
          ),
          data: (data) {
            final nps = (data['nps'] ?? 0).toDouble();
            final ratingDistribution =
                (data['ratingDistribution'] as Map<String, dynamic>?) ?? {};
            final locationNps =
                (data['locationNps'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];
            final recentFeedback =
                (data['recentFeedback'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NPS Score gauge
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            theme.colorScheme.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text('Net Promoter Score',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: const Color(0xFF64748B))),
                          const SizedBox(height: 12),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _npsColor(nps).withOpacity(0.1),
                              border: Border.all(
                                  color: _npsColor(nps), width: 4),
                            ),
                            child: Center(
                              child: Text(
                                nps.toStringAsFixed(0),
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _npsColor(nps),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nps >= 50
                                ? 'Excellent'
                                : nps >= 0
                                    ? 'Good'
                                    : 'Needs Improvement',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _npsColor(nps),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Rating distribution
                  Text('Rating Distribution',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            theme.colorScheme.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: List.generate(5, (i) {
                          final star = 5 - i;
                          final count = (ratingDistribution['$star'] ?? 0)
                              .toDouble();
                          final total = ratingDistribution.values
                              .fold<double>(
                                  0, (sum, v) => sum + (v as num).toDouble());
                          final pct = total > 0 ? count / total : 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text('$star',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                ),
                                const Icon(Icons.star,
                                    size: 16, color: Color(0xFFFBBF24)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 12,
                                      backgroundColor: theme.colorScheme
                                          .surfaceContainerLow,
                                      color: _barColor(star),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${count.toInt()}',
                                    style: theme.textTheme.labelMedium,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Location-wise NPS
                  if (locationNps.isNotEmpty) ...[
                    Text('Location NPS',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withOpacity(0.4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: locationNps.map((loc) {
                            final locName = loc['name'] ?? '-';
                            final locNps = (loc['nps'] ?? 0).toDouble();
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(locName,
                                        style: theme.textTheme.bodyMedium),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _npsColor(locNps)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      locNps.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _npsColor(locNps),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Recent feedback comments
                  Text('Recent Feedback',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (recentFeedback.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No recent feedback',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF94A3B8))),
                    )
                  else
                    ...recentFeedback.map((fb) {
                      final comment = fb['comment'] ?? fb['text'] ?? '';
                      final rating = (fb['rating'] ?? 0).toInt();
                      final customerName =
                          fb['customerName'] ?? fb['customer']?['name'] ?? 'Anonymous';
                      final date = DateTime.tryParse(
                          (fb['createdAt'] ?? '').toString());

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: const Color(0xFFFBBF24),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (date != null)
                                    Text(
                                      formatDate(date),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color:
                                                  const Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (comment.toString().isNotEmpty)
                                Text(
                                  comment.toString(),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(height: 1.4),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '- $customerName',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _barColor(int star) {
    switch (star) {
      case 5:
        return const Color(0xFF16A34A);
      case 4:
        return const Color(0xFF84CC16);
      case 3:
        return const Color(0xFFFBBF24);
      case 2:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFFDC2626);
    }
  }
}
