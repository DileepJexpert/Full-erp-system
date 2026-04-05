import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import 'feedback_provider.dart';

class FeedbackDashboardScreen extends ConsumerStatefulWidget {
  const FeedbackDashboardScreen({super.key});

  @override
  ConsumerState<FeedbackDashboardScreen> createState() =>
      _FeedbackDashboardScreenState();
}

class _FeedbackDashboardScreenState
    extends ConsumerState<FeedbackDashboardScreen> {
  String? _selectedLocationId;
  DateTimeRange? _dateRange;

  DashboardFilter get _filter => DashboardFilter(
        locationId: _selectedLocationId,
        startDate: _dateRange?.start.toIso8601String().split('T').first,
        endDate: _dateRange?.end.toIso8601String().split('T').first,
      );

  Color _npsColor(double nps) {
    if (nps > 50) return AppTheme.successColor;
    if (nps >= 0) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _npsLabel(double nps) {
    if (nps > 50) return 'Excellent';
    if (nps >= 0) return 'Good';
    return 'Needs Improvement';
  }

  Color _barColor(int star) {
    switch (star) {
      case 5:
        return const Color(0xFF22C55E);
      case 4:
        return const Color(0xFF84CC16);
      case 3:
        return const Color(0xFFFBBF24);
      case 2:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _ratingEmoji(int rating) {
    const emojis = [
      '\uD83D\uDE21',
      '\uD83D\uDE15',
      '\uD83D\uDE10',
      '\uD83D\uDE0A',
      '\uD83E\uDD29',
    ];
    if (rating >= 1 && rating <= 5) return emojis[rating - 1];
    return '\uD83D\uDE10';
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(dashboardSummaryProvider(_filter));
    final npsAsync = ref.watch(dashboardNpsProvider(_filter));
    final listAsync = ref.watch(dashboardFeedbackListProvider(_filter));
    final locationsAsync = ref.watch(dashboardLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Feedback'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardSummaryProvider(_filter));
              ref.invalidate(dashboardNpsProvider(_filter));
              ref.invalidate(dashboardFeedbackListProvider(_filter));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider(_filter));
          ref.invalidate(dashboardNpsProvider(_filter));
          ref.invalidate(dashboardFeedbackListProvider(_filter));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters row
              _buildFilters(theme, locationsAsync),
              const SizedBox(height: 20),

              // Top metric cards
              _buildTopCards(theme, summaryAsync, npsAsync),
              const SizedBox(height: 24),

              // Rating distribution
              Text('Rating Distribution',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildRatingDistribution(theme, summaryAsync),
              const SizedBox(height: 24),

              // Top tags
              Text('Top Tags',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildTopTags(theme, summaryAsync),
              const SizedBox(height: 24),

              // Location comparison
              _buildLocationComparison(theme, npsAsync),
              const SizedBox(height: 24),

              // Recent feedback
              Text('Recent Feedback',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildRecentFeedback(theme, listAsync),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Filters ──────────────────────────────────────────

  Widget _buildFilters(
      ThemeData theme, AsyncValue<List<Map<String, dynamic>>> locationsAsync) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // Location filter
        locationsAsync.when(
          loading: () => const SizedBox(
            width: 200,
            child: LinearProgressIndicator(),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (locations) => SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _selectedLocationId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Location',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All Locations')),
                ...locations.map((l) => DropdownMenuItem(
                      value: (l['id'] ?? l['_id'] ?? '').toString(),
                      child: Text(l['name']?.toString() ?? 'Unknown'),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedLocationId = val),
            ),
          ),
        ),
        // Date range
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(
            _dateRange != null
                ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                : 'Date Range',
          ),
          onPressed: _pickDateRange,
        ),
        if (_dateRange != null)
          ActionChip(
            avatar: const Icon(Icons.clear, size: 18),
            label: const Text('Clear'),
            onPressed: () => setState(() => _dateRange = null),
          ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  // ─── Top Cards ────────────────────────────────────────

  Widget _buildTopCards(
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> summaryAsync,
    AsyncValue<Map<String, dynamic>> npsAsync,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 600
            ? (constraints.maxWidth - 32) / 3
            : constraints.maxWidth;
        final isWide = constraints.maxWidth > 600;

        final cards = [
          // NPS Score
          npsAsync.when(
            loading: () => _metricCardSkeleton(cardWidth),
            error: (_, __) => _metricCard(
              width: cardWidth,
              theme: theme,
              title: 'NPS Score',
              value: '--',
              color: const Color(0xFF94A3B8),
              subtitle: 'Error loading',
            ),
            data: (data) {
              final nps = (data['nps'] ?? 0).toDouble();
              return _metricCard(
                width: cardWidth,
                theme: theme,
                title: 'NPS Score',
                value: nps.toStringAsFixed(0),
                color: _npsColor(nps),
                subtitle: _npsLabel(nps),
              );
            },
          ),
          // Average Rating
          summaryAsync.when(
            loading: () => _metricCardSkeleton(cardWidth),
            error: (_, __) => _metricCard(
              width: cardWidth,
              theme: theme,
              title: 'Avg Rating',
              value: '--',
              color: const Color(0xFF94A3B8),
              subtitle: 'Error loading',
              icon: Icons.star,
            ),
            data: (data) {
              final avg = (data['averageRating'] ?? 0).toDouble();
              return _metricCard(
                width: cardWidth,
                theme: theme,
                title: 'Avg Rating',
                value: avg.toStringAsFixed(1),
                color: const Color(0xFFFBBF24),
                subtitle: '${_ratingEmoji(avg.round())} out of 5',
                icon: Icons.star,
              );
            },
          ),
          // Total Feedback
          summaryAsync.when(
            loading: () => _metricCardSkeleton(cardWidth),
            error: (_, __) => _metricCard(
              width: cardWidth,
              theme: theme,
              title: 'Total Feedback',
              value: '--',
              color: const Color(0xFF94A3B8),
              subtitle: 'Error loading',
            ),
            data: (data) {
              final total = (data['totalCount'] ?? 0).toInt();
              return _metricCard(
                width: cardWidth,
                theme: theme,
                title: 'Total Feedback',
                value: total.toString(),
                color: AppTheme.primaryColor,
                subtitle: 'responses',
              );
            },
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((c) => Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    )))
                .toList(),
          );
        }
        return Column(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _metricCard({
    required double width,
    required ThemeData theme,
    required String title,
    required String value,
    required Color color,
    required String subtitle,
    IconData? icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                ],
                Text(title,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: const Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCardSkeleton(double width) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Rating Distribution ──────────────────────────────

  Widget _buildRatingDistribution(
      ThemeData theme, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e'),
        ),
      ),
      data: (data) {
        final dist =
            (data['ratingDistribution'] as Map<String, dynamic>?) ?? {};
        final total = dist.values
            .fold<double>(0, (sum, v) => sum + (v as num).toDouble());

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = (dist['$star'] ?? 0).toDouble();
                final pct = total > 0 ? count / total : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$star',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.star,
                          size: 16, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 14,
                            backgroundColor:
                                const Color(0xFFF1F5F9),
                            color: _barColor(star),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${count.toInt()}',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF94A3B8),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // ─── Top Tags ─────────────────────────────────────────

  Widget _buildTopTags(
      ThemeData theme, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final topTags =
            (data['topTags'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (topTags.isEmpty) {
          return Text('No tag data yet',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF94A3B8)));
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topTags.map((t) {
            final tag = t['tag']?.toString() ?? '';
            final count = (t['count'] ?? 0).toInt();
            final info = _tagLabels[tag];
            final emoji = info?['emoji'] ?? '';
            final label = info?['en'] ?? tag;

            return Chip(
              avatar: emoji.isNotEmpty ? Text(emoji) : null,
              label: Text('$label ($count)'),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
            );
          }).toList(),
        );
      },
    );
  }

  static const _tagLabels = <String, Map<String, String>>{
    'slow_service': {'en': 'Slow Service', 'emoji': '\uD83D\uDC0C'},
    'bad_quality': {'en': 'Bad Quality', 'emoji': '\uD83D\uDC4E'},
    'rude_staff': {'en': 'Rude Staff', 'emoji': '\uD83D\uDE24'},
    'wrong_order': {'en': 'Wrong Order', 'emoji': '\u274C'},
    'not_clean': {'en': 'Not Clean', 'emoji': '\uD83E\uDDF9'},
    'overpriced': {'en': 'Overpriced', 'emoji': '\uD83D\uDCB0'},
    'tasty_food': {'en': 'Tasty Food', 'emoji': '\uD83D\uDE0B'},
    'fast_service': {'en': 'Fast Service', 'emoji': '\u26A1'},
    'friendly_staff': {'en': 'Friendly Staff', 'emoji': '\uD83D\uDE0A'},
    'clean_place': {'en': 'Clean Place', 'emoji': '\u2728'},
    'good_value': {'en': 'Good Value', 'emoji': '\uD83D\uDC8E'},
    'will_recommend': {'en': 'Will Recommend', 'emoji': '\uD83D\uDC4D'},
  };

  // ─── Location Comparison ──────────────────────────────

  Widget _buildLocationComparison(
      ThemeData theme, AsyncValue<Map<String, dynamic>> npsAsync) {
    return npsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final locations =
            (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (locations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location Comparison',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      children: [
                        _tableHeader(theme, 'Location'),
                        _tableHeader(theme, 'Avg Rating'),
                        _tableHeader(theme, 'Count'),
                        _tableHeader(theme, 'NPS'),
                      ],
                    ),
                    ...locations.map((loc) {
                      final name = loc['name']?.toString() ?? '-';
                      final avgRating =
                          (loc['averageRating'] ?? 0).toDouble();
                      final count = (loc['count'] ?? 0).toInt();
                      final nps = (loc['nps'] ?? 0).toDouble();

                      return TableRow(
                        children: [
                          _tableCell(theme, name),
                          _tableCell(theme,
                              '${_ratingEmoji(avgRating.round())} ${avgRating.toStringAsFixed(1)}'),
                          _tableCell(theme, count.toString()),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _npsColor(nps).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                nps.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _npsColor(nps),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tableHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _tableCell(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }

  // ─── Recent Feedback List ─────────────────────────────

  Widget _buildRecentFeedback(
      ThemeData theme, AsyncValue<List<Map<String, dynamic>>> listAsync) {
    return listAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (feedbacks) {
        if (feedbacks.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No feedback yet',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: const Color(0xFF94A3B8)),
                ),
              ),
            ),
          );
        }

        return Column(
          children: feedbacks.take(20).map((fb) {
            final rating = (fb['rating'] ?? 3).toInt();
            final comment = fb['comment']?.toString() ?? '';
            final tags =
                (fb['tags'] as List?)?.cast<String>() ?? [];
            final location = fb['locationName']?.toString() ?? '';
            final createdAt =
                DateTime.tryParse(fb['createdAt']?.toString() ?? '');
            final timeAgo = createdAt != null
                ? _timeAgo(createdAt)
                : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _ratingEmoji(rating),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 10),
                        // Stars
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < rating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: const Color(0xFFFBBF24),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (location.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              location,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(height: 1.4),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: tags.map((t) {
                          final info = _tagLabels[t];
                          final label =
                              info != null ? '${info['emoji']} ${info['en']}' : t;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
