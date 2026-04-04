import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

export 'app_database.dart';

/// Singleton Riverpod provider for the Drift database.
///
/// Uses [NativeDatabase.createInBackground] so all heavy SQLite I/O runs on an
/// isolate, keeping the UI thread free.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(_openConnection());
  ref.onDispose(() => db.close());
  return db;
});

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'business_manager.sqlite'));
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
