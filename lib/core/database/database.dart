import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/events/domain/event.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Events])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // v1 → v2: add photoPath
        await migrator.addColumn(events, events.photoPath);
      }
      if (from < 3) {
        // v2 → v3: targetDate is now nullable; add eventType, tallyCount,
        // resetPeriod, lastResetAt.
        await migrator.deleteTable('events');
        await migrator.createTable(events);
      }
      if (from < 4) {
        // v3 → v4: add repeatPeriod for countdown / count-up recurrence.
        await migrator.addColumn(events, events.repeatPeriod);
      }
      if (from < 5) {
        // v4 → v5: persist reminder preference per event so the detail
        // sheet can restore the user's last selection on reopen.
        await migrator.addColumn(events, events.reminderType);
        await migrator.addColumn(events, events.reminderCustomSecs);
      }
    },
  );

  static QueryExecutor _openDatabase() =>
      driftDatabase(name: 'countdown_db');
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}