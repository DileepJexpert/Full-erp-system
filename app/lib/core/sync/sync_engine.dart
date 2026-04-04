import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../api/api_client.dart';
import '../auth/auth_provider.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../providers/connectivity_provider.dart';
import 'sync_status.dart';

/// Processes the offline [SyncQueue] and refreshes local caches when
/// connectivity is available.
///
/// Usage:
/// ```dart
/// final engine = ref.read(syncEngineProvider);
/// engine.startPeriodicSync();
/// ```
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _api;
  final SyncNotifier _syncNotifier;
  final Ref _ref;

  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  SyncEngine({
    required AppDatabase db,
    required ApiClient api,
    required SyncNotifier syncNotifier,
    required Ref ref,
  })  : _db = db,
        _api = api,
        _syncNotifier = syncNotifier,
        _ref = ref;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Start listening to connectivity changes and run a periodic sync timer.
  void startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      AppConstants.syncInterval,
      (_) => syncNow(),
    );

    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        // Connectivity restored -- trigger an immediate sync.
        syncNow();
      } else {
        _syncNotifier.markOffline();
      }
    });

    // Run once immediately on start.
    syncNow();
  }

  /// Trigger a single sync cycle. Safe to call multiple times; concurrent
  /// invocations are coalesced.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        _syncNotifier.markOffline();
        return;
      }

      _syncNotifier.setStatus(SyncStatus.syncing);

      // 1. Process the pending sync queue (offline mutations).
      await _processSyncQueue();

      // 2. Sync pending bills that were saved offline.
      await _syncPendingBills();

      // 3. Refresh caches from the server.
      await _refreshItemsCache();

      // 4. Update pending count.
      final remaining = await _db.getPendingSyncCount();
      final unsyncedBills = await _db.getUnsyncedBillCount();
      final total = remaining + unsyncedBills;
      _syncNotifier.setPendingCount(total);

      if (total == 0) {
        _syncNotifier.markSynced();
      } else {
        _syncNotifier.setStatus(SyncStatus.idle);
      }

      // 5. Clean up synced bills older than 7 days.
      await _db.deleteSyncedBills();
    } catch (e, st) {
      dev.log('SyncEngine error: $e', stackTrace: st);
      _syncNotifier.markError(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Cancel timers and subscriptions. Call on logout / dispose.
  void stopSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _syncNotifier.reset();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _processSyncQueue() async {
    final entries = await _db.getPendingSync();
    for (final entry in entries) {
      if (entry.retryCount >= AppConstants.maxSyncRetries) {
        dev.log('SyncQueue: dropping dead-letter entry ${entry.id}');
        await _db.removeSyncEntry(entry.id);
        continue;
      }

      try {
        await _replayRequest(entry);
        await _db.removeSyncEntry(entry.id);
      } catch (e) {
        dev.log('SyncQueue: retry ${entry.retryCount + 1} failed for '
            '${entry.method} ${entry.endpoint}: $e');
        await _db.incrementRetry(entry.id);

        // Exponential backoff: 2^retryCount seconds (cap at 32 s).
        final delaySeconds = _exponentialDelay(entry.retryCount);
        await Future<void>.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  Future<void> _replayRequest(SyncQueueData entry) async {
    final data =
        entry.payload.isNotEmpty ? jsonDecode(entry.payload) : null;

    switch (entry.method.toUpperCase()) {
      case 'POST':
        await _api.post(entry.endpoint, data: data);
      case 'PUT':
        await _api.put(entry.endpoint, data: data);
      case 'PATCH':
        await _api.patch(entry.endpoint, data: data);
      case 'DELETE':
        await _api.delete(entry.endpoint);
      default:
        dev.log('SyncQueue: unsupported method ${entry.method}');
    }

    // If this entry is correlated with a pending bill, mark it synced.
    if (entry.correlationId != null) {
      await _db.markBillSynced(entry.correlationId!);
    }
  }

  Future<void> _syncPendingBills() async {
    final bills = await _db.getUnsyncedBills();
    for (final bill in bills) {
      try {
        final data = jsonDecode(bill.billJson);
        await _api.post('/billing', data: data);
        await _db.markBillSynced(bill.id);
      } catch (e) {
        dev.log('SyncEngine: failed to sync bill ${bill.id}: $e');
        // Will be retried on next cycle.
      }
    }
  }

  Future<void> _refreshItemsCache() async {
    try {
      final response = await _api.get('/inventory', queryParameters: {
        'limit': '500',
        'isActive': 'true',
      });
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;

      final companions = list.map((json) {
        final j = json as Map<String, dynamic>;
        return CachedItemsCompanion(
          id: Value(j['id'] as String),
          name: Value(j['name'] as String? ?? ''),
          category: Value(j['category'] as String? ?? ''),
          unit: Value(j['unit'] as String? ?? ''),
          sellPrice: Value((j['sellPrice'] ?? 0).toDouble()),
          costPrice: Value((j['costPrice'] ?? 0).toDouble()),
          gstRate: Value((j['gstRate'] ?? 0).toDouble()),
          isActive: Value(j['isActive'] as bool? ?? true),
          updatedAt: Value(DateTime.now()),
        );
      }).toList();

      await _db.replaceAllItems(companions);
    } catch (e) {
      dev.log('SyncEngine: failed to refresh items cache: $e');
      // Non-fatal -- stale cache is acceptable.
    }
  }

  int _exponentialDelay(int retryCount) {
    // 1, 2, 4, 8, 16 -- capped at 32 seconds.
    final delay = 1 << retryCount;
    return delay.clamp(1, 32);
  }
}

// -----------------------------------------------------------------------------
// Provider
// -----------------------------------------------------------------------------

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.read(databaseProvider);
  final api = ref.read(apiClientProvider);
  final notifier = ref.read(syncNotifierProvider.notifier);

  final engine = SyncEngine(
    db: db,
    api: api,
    syncNotifier: notifier,
    ref: ref,
  );

  ref.onDispose(() => engine.stopSync());
  return engine;
});
