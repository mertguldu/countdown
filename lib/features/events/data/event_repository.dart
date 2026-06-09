import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../domain/event.dart';

part 'event_repository.g.dart';

class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  Stream<List<Event>> watchFiltered(EventFilter filter) {
    final now = DateTime.now();
    final q = _db.select(_db.events);

    switch (filter) {
      case EventFilter.upcoming:
        q
          ..where((t) => t.targetDate.isBiggerThanValue(now))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),    // ← respect manual order
            (t) => OrderingTerm.asc(t.targetDate),   //   date as tiebreaker
          ]);
      case EventFilter.past:
        q
          ..where((t) => t.targetDate.isSmallerOrEqualValue(now))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),    // ← respect manual order
            (t) => OrderingTerm.desc(t.targetDate),  //   most recent first as tiebreaker
          ]);
      case EventFilter.all:
        q.orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.targetDate),
        ]);
      case EventFilter.byDateAsc:
        q.orderBy([(t) => OrderingTerm.asc(t.targetDate)]);
      case EventFilter.byDateDesc:
        q.orderBy([(t) => OrderingTerm.desc(t.targetDate)]);
    }

    return q.watch();
  }

  Future<int> insertEvent(EventsCompanion companion) =>
      _db.into(_db.events).insert(companion);

  Future<bool> updateEvent(EventsCompanion companion) =>
      _db.update(_db.events).replace(companion);

  Future<int> deleteEvent(int id) =>
      (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();

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

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    EventRepository(ref.watch(appDatabaseProvider));