import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum SyncState { synced, pending, offline }

class SyncIndicator extends StatelessWidget {
  final SyncState state;
  final bool showLabel;

  const SyncIndicator({super.key, required this.state, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      SyncState.synced => (AppTheme.syncedColor, 'Synced'),
      SyncState.pending => (AppTheme.pendingColor, 'Pending'),
      SyncState.offline => (AppTheme.offlineColor, 'Offline'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
