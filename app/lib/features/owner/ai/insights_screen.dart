import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';
import 'ai_chat_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  static const _categoryColors = {
    'revenue': Color(0xFF16A34A),
    'wastage': Color(0xFFDC2626),
    'inventory': Color(0xFFD97706),
    'staff': Color(0xFF2563EB),
    'customer': Color(0xFF7C3AED),
  };

  Color _colorForCategory(String? category) {
    return _categoryColors[category?.toLowerCase()] ?? const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(aiInsightsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(aiInsightsProvider),
        child: insightsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LoadingSkeleton.card(),
              ),
            ),
          ),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ErrorView(
              message: err.toString(),
              onRetry: () => ref.invalidate(aiInsightsProvider),
            ),
          ),
          data: (insights) {
            if (insights.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: EmptyState(
                  icon: Icons.lightbulb_outline,
                  title: 'No insights yet',
                  subtitle: 'AI-generated insights will appear here.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final insight = insights[index];
                final title = insight['title'] ?? 'Insight';
                final description = insight['description'] ?? '';
                final category = (insight['category'] ?? '').toString();
                final id = insight['id']?.toString() ?? '';
                final color = _colorForCategory(category);

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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                try {
                                  final api = ref.read(apiClientProvider);
                                  await api.post('/ai/insights/$id/dismiss');
                                  ref.invalidate(aiInsightsProvider);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Failed to dismiss insight')),
                                    );
                                  }
                                }
                              },
                              tooltip: 'Dismiss',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
