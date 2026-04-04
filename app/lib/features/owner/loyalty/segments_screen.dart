import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../core/auth/auth_provider.dart';

final customerSegmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/loyalty/segments');
  final data = response.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  if (data is Map && data['data'] != null) {
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class SegmentsScreen extends ConsumerWidget {
  const SegmentsScreen({super.key});

  static const _segmentConfig = {
    'champions': _SegmentStyle(Color(0xFFFBBF24), Color(0xFF92400E), Icons.emoji_events),
    'loyal': _SegmentStyle(Color(0xFF2563EB), Color(0xFF1E40AF), Icons.favorite),
    'at_risk': _SegmentStyle(Color(0xFFDC2626), Color(0xFF991B1B), Icons.warning_amber),
    'new': _SegmentStyle(Color(0xFF16A34A), Color(0xFF166534), Icons.fiber_new),
    'dormant': _SegmentStyle(Color(0xFF64748B), Color(0xFF334155), Icons.hotel),
  };

  static _SegmentStyle _styleFor(String? segment) {
    return _segmentConfig[segment?.toLowerCase()] ??
        const _SegmentStyle(Color(0xFF64748B), Color(0xFF334155), Icons.people);
  }

  static String? _actionFor(String? segment) {
    switch (segment?.toLowerCase()) {
      case 'at_risk':
        return 'Send Win-back Campaign';
      case 'champions':
        return 'Send Exclusive Offer';
      case 'loyal':
        return 'Send Loyalty Reward';
      case 'new':
        return 'Send Welcome Offer';
      case 'dormant':
        return 'Send Re-engagement';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(customerSegmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Segments'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(customerSegmentsProvider),
        child: segmentsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              5,
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
              onRetry: () => ref.invalidate(customerSegmentsProvider),
            ),
          ),
          data: (segments) {
            if (segments.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No segments data available',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: const Color(0xFF94A3B8))),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: segments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final seg = segments[index];
                final name = (seg['name'] ?? seg['segment'] ?? '').toString();
                final count = seg['customerCount'] ?? seg['count'] ?? 0;
                final avgSpend = (seg['avgSpend'] ?? 0).toDouble();
                final style = _styleFor(name);
                final action = _actionFor(name);
                final id = seg['id']?.toString() ?? '';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: style.color.withOpacity(0.3),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Navigate to customer list for this segment
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: style.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(style.icon,
                                    color: style.darkColor, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.replaceAll('_', ' ').toUpperCase(),
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: style.darkColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$count customers',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Avg Spend',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: const Color(0xFF94A3B8))),
                                  Text(
                                    formatRupee(avgSpend),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (action != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  try {
                                    final api = ref.read(apiClientProvider);
                                    await api.post(
                                        '/loyalty/segments/$id/campaign');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('$action sent!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: style.darkColor,
                                  side: BorderSide(
                                      color: style.color.withOpacity(0.5)),
                                ),
                                child: Text(action),
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _SegmentStyle {
  final Color color;
  final Color darkColor;
  final IconData icon;

  const _SegmentStyle(this.color, this.darkColor, this.icon);
}
