import 'package:flutter_riverpod/flutter_riverpod.dart';

/// High-level sync status visible to the UI layer.
enum SyncStatus {
  /// No sync operation in progress, everything is up-to-date.
  idle,

  /// A sync cycle is currently running.
  syncing,

  /// Last sync cycle completed successfully with no pending items.
  synced,

  /// Last sync cycle encountered one or more errors.
  error,

  /// Device has no network connectivity.
  offline,
}

/// Immutable snapshot of the current synchronization state.
class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final String? lastError;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.lastError,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncTime,
    String? lastError,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: lastError,
    );
  }

  bool get hasPending => pendingCount > 0;

  @override
  String toString() =>
      'SyncState(status: $status, pending: $pendingCount, lastSync: $lastSyncTime)';
}

/// [StateNotifier] that the [SyncEngine] mutates and widgets observe.
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState());

  void setStatus(SyncStatus status) {
    state = state.copyWith(status: status);
  }

  void setPendingCount(int count) {
    state = state.copyWith(pendingCount: count);
  }

  void markSynced() {
    state = state.copyWith(
      status: SyncStatus.synced,
      lastSyncTime: DateTime.now(),
      lastError: null,
    );
  }

  void markError(String message) {
    state = state.copyWith(status: SyncStatus.error, lastError: message);
  }

  void markOffline() {
    state = state.copyWith(status: SyncStatus.offline);
  }

  void reset() {
    state = const SyncState();
  }
}

/// Global provider for sync state.
final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});
