import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../domain/event.dart';

part 'event_repository.g.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  // ── Queries ─────────────────────────────────────────────────────────────────

  /// Streams events matching [filter], ordered appropriately for each tab.
  ///
  /// Note: [DateTime.now()] is snapshotted at subscription time. The filter
  /// stays accurate for normal session lengths; no periodic refresh needed.
  Stream<List<Event>> watchFiltered(EventFilter filter) {
    final now = DateTime.now();
    final q = _db.select(_db.events);

    switch (filter) {
      case EventFilter.upcoming:
        q
          ..where((t) => t.targetDate.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]);
      case EventFilter.past:
        q
          ..where((t) => t.targetDate.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.desc(t.targetDate)]);
      case EventFilter.all:
        q.orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.targetDate),
        ]);
    }

    return q.watch();
  }

  // ── Writes ──────────────────────────────────────────────────────────────────

  Future<int> insertEvent(EventsCompanion companion) =>
      _db.into(_db.events).insert(companion);

  Future<bool> updateEvent(EventsCompanion companion) =>
      _db.update(_db.events).replace(companion);

  Future<int> deleteEvent(int id) =>
      (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();

  /// Batch-update sort orders after a drag-reorder gesture.
  Future<void> reorder(List<({int id, int sortOrder})> updates) =>
      _db.batch((batch) {
        for (final u in updates) {
          batch.update(
            _db.events,
            EventsCompanion(sortOrder: Value(u.sortOrder)),
            where: (t) => t.id.equals(u.id),
          );
        }
      });
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    EventRepository(ref.watch(appDatabaseProvider));