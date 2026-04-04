import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/date.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import 'performance_provider.dart';

class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(performanceScoresProvider);
    final dateRange = ref.watch(performanceDateRangeProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(performanceScoresProvider),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Performance',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Leaderboard and score breakdown',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _selectDateRange(context, ref),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    '${formatDate(dateRange.start)} - ${formatDate(dateRange.end)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            scoresAsync.when(
              loading: () => Column(
                children: List.generate(
                  5,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LoadingSkeleton.card(),
                  ),
                ),
              ),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(performanceScoresProvider),
              ),
              data: (scores) {
                if (scores.isEmpty) {
                  return const EmptyState(
                    icon: Icons.leaderboard_outlined,
                    title: 'No performance data',
                    subtitle: 'No scores available for the selected date range.',
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < scores.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PerformanceCard(score: scores[i], rank: i + 1),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(performanceDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(performanceDateRangeProvider.notifier).state = picked;
    }
  }
}

class _PerformanceCard extends StatefulWidget {
  final PerformanceScore score;
  final int rank;

  const _PerformanceCard({required this.score, required this.rank});

  @override
  State<_PerformanceCard> createState() => _PerformanceCardState();
}

class _PerformanceCardState extends State<_PerformanceCard> {
  bool _expanded = false;

  Color get _scoreColor {
    if (widget.score.totalScore >= 80) return const Color(0xFF16A34A);
    if (widget.score.totalScore >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final rankDecoration = switch (widget.rank) {
      1 => const BoxDecoration(
          color: Color(0xFFFEF3C7),
          shape: BoxShape.circle,
        ),
      2 => const BoxDecoration(
          color: Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
      3 => const BoxDecoration(
          color: Color(0xFFFED7AA),
          shape: BoxShape.circle,
        ),
      _ => BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
    };

    final rankIcon = switch (widget.rank) {
      1 => const Icon(Icons.emoji_events, size: 18, color: Color(0xFFD97706)),
      2 => const Icon(Icons.emoji_events, size: 18, color: Color(0xFF64748B)),
      3 => const Icon(Icons.emoji_events, size: 18, color: Color(0xFFEA580C)),
      _ => null,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: rankDecoration,
                    child: Center(
                      child: rankIcon ??
                          Text(
                            '${widget.rank}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.score.staffName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              widget.score.locationName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.score.totalScore.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _scoreColor,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: widget.score.breakdown.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ScoreBar(label: entry.key, value: entry.value),
                      );
                    }).toList(),
                  ),
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;

  const _ScoreBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? const Color(0xFF16A34A)
        : value >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(0),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
