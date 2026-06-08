import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/events/domain/event.dart';

part 'database.g.dart';

// Tables are added to this list as features are built.
// The list in @DriftDatabase and the schemas.dart barrel export must stay
// in sync — if a table is exported from schemas.dart it must be listed here.
@DriftDatabase(tables: [
  Events,
  // Counters and DailyCounts will be added here as the counter feature is built.
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());

  @override
  int get schemaVersion => 1;

  // Migration strategy: bump schemaVersion and add a MigrationStrategy here
  // before any release that changes the schema.
  // @override
  // MigrationStrategy get migration => MigrationStrategy(
  //   onUpgrade: (migrator, from, to) async { ... },
  // );

  static QueryExecutor _openDatabase() {
    // drift_flutter picks the right SQLite implementation per platform
    // and stores the file in the app's documents directory.
    return driftDatabase(name: 'countdown_db');
  }
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  // Closes the database connection cleanly if the provider is ever disposed.
  ref.onDispose(db.close);
  return db;
}