import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Offline storage for pending POS bills awaiting server sync.
class PendingBills extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get billJson => text()(); // Full bill JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local cache of inventory items for offline POS operation.
class CachedItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get unit => text()();
  RealColumn get sellPrice => real()();
  RealColumn get costPrice => real()();
  RealColumn get gstRate => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local cache of dispatch records.
class CachedDispatches extends Table {
  TextColumn get id => text()();
  TextColumn get dispatchJson => text()();
  DateTimeColumn get dispatchDate => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// FIFO queue of API calls waiting to be replayed when connectivity restores.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get endpoint => text()();
  TextColumn get method => text()(); // POST, PUT, DELETE
  TextColumn get payload => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get correlationId => text().nullable()(); // links to PendingBill id
}

@DriftDatabase(tables: [PendingBills, CachedItems, CachedDispatches, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations go here
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PendingBills
  // ---------------------------------------------------------------------------

  Future<List<PendingBill>> getUnsyncedBills() =>
      (select(pendingBills)..where((t) => t.synced.equals(false))).get();

  Stream<List<PendingBill>> watchUnsyncedBills() =>
      (select(pendingBills)..where((t) => t.synced.equals(false))).watch();

  Future<int> getUnsyncedBillCount() async {
    final count = countAll();
    final query = selectOnly(pendingBills)
      ..addColumns([count])
      ..where(pendingBills.synced.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> insertBill(PendingBillsCompanion bill) =>
      into(pendingBills).insert(bill);

  Future<void> markBillSynced(String billId) =>
      (update(pendingBills)..where((t) => t.id.equals(billId)))
          .write(const PendingBillsCompanion(synced: Value(true)));

  Future<void> deleteSyncedBills() =>
      (delete(pendingBills)..where((t) => t.synced.equals(true))).go();

  // ---------------------------------------------------------------------------
  // CachedItems
  // ---------------------------------------------------------------------------

  Future<List<CachedItem>> getAllItems() => select(cachedItems).get();

  Stream<List<CachedItem>> watchAllItems() => select(cachedItems).watch();

  Future<List<CachedItem>> getActiveItems() =>
      (select(cachedItems)..where((t) => t.isActive.equals(true))).get();

  Future<List<CachedItem>> searchItems(String query) {
    final pattern = '%$query%';
    return (select(cachedItems)
          ..where((t) =>
              t.name.like(pattern) | t.category.like(pattern)))
        .get();
  }

  Future<void> upsertItem(CachedItemsCompanion item) =>
      into(cachedItems).insertOnConflictUpdate(item);

  Future<void> replaceAllItems(List<CachedItemsCompanion> items) async {
    await transaction(() async {
      await delete(cachedItems).go();
      await batch((b) {
        b.insertAll(cachedItems, items);
      });
    });
  }

  // ---------------------------------------------------------------------------
  // CachedDispatches
  // ---------------------------------------------------------------------------

  Future<List<CachedDispatch>> getAllDispatches() =>
      (select(cachedDispatches)
            ..orderBy([(t) => OrderingTerm.desc(t.dispatchDate)]))
          .get();

  Future<void> upsertDispatch(CachedDispatchesCompanion dispatch) =>
      into(cachedDispatches).insertOnConflictUpdate(dispatch);

  // ---------------------------------------------------------------------------
  // SyncQueue
  // ---------------------------------------------------------------------------

  Future<List<SyncQueueData>> getPendingSync() =>
      (select(syncQueue)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<SyncQueueData>> watchPendingSync() =>
      (select(syncQueue)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<int> getPendingSyncCount() async {
    final count = countAll();
    final query = selectOnly(syncQueue)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> addToSyncQueue(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  Future<void> removeSyncEntry(int entryId) =>
      (delete(syncQueue)..where((t) => t.id.equals(entryId))).go();

  Future<void> incrementRetry(int entryId) => customUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
        variables: [Variable.withInt(entryId)],
        updates: {syncQueue},
      );

  Future<void> removeDeadLetters(int maxRetries) =>
      (delete(syncQueue)..where((t) => t.retryCount.isBiggerOrEqualValue(maxRetries)))
          .go();

  /// Remove all data -- used on logout.
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(pendingBills).go();
      await delete(cachedItems).go();
      await delete(cachedDispatches).go();
      await delete(syncQueue).go();
    });
  }
}
