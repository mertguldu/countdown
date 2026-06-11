import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../domain/event.dart';

part 'event_repository.g.dart';

class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All countdown events, with optional date/sort filters.
  /// Multiple .where() calls REPLACE each other in Drift, so we combine
  /// conditions with the & operator in a single .where() call.
  Stream<List<Event>> watchFiltered(EventFilter filter) {
    final now = DateTime.now();
    final q   = _db.select(_db.events);
    final isCountdown = (Events t) =>
        t.eventType.equals(EventType.countdown.name);

    switch (filter) {
      case EventFilter.upcoming:
        q
          ..where((t) =>
              isCountdown(t) & t.targetDate.isBiggerThanValue(now))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.targetDate),
          ]);
      case EventFilter.past:
        q
          ..where((t) =>
              isCountdown(t) & t.targetDate.isSmallerOrEqualValue(now))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.targetDate),
          ]);
      case EventFilter.all:
        q
          ..where(isCountdown)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.targetDate),
          ]);
      case EventFilter.byDateAsc:
        q
          ..where(isCountdown)
          ..orderBy([(t) => OrderingTerm.asc(t.targetDate)]);
      case EventFilter.byDateDesc:
        q
          ..where(isCountdown)
          ..orderBy([(t) => OrderingTerm.desc(t.targetDate)]);
    }
    return q.watch();
  }

  /// All events of the given type, ordered by sortOrder then targetDate.
  Stream<List<Event>> watchByType(EventType type) =>
      (_db.select(_db.events)
            ..where((t) => t.eventType.equals(type.name))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.targetDate),
            ]))
          .watch();

  // ── CRUD ─────────────────────────────────────────────────────────────────

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

  // ── Tally ─────────────────────────────────────────────────────────────────

  /// Increment (+1) or decrement (−1) a tally counter, floor at 0.
  Future<void> adjustTallyCount(int id, int delta) =>
      _db.customUpdate(
        'UPDATE events SET tally_count = MAX(0, tally_count + ?) WHERE id = ?',
        variables: [Variable.withInt(delta), Variable.withInt(id)],
        updates: {_db.events},
      );

  Future<void> resetTally(int id) =>
      (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
        EventsCompanion(
          tallyCount:  const Value(0),
          lastResetAt: Value(DateTime.now()),
        ),
      );

  /// Auto-reset any tally counters whose period has elapsed since last reset.
  Future<void> processAutoResets(List<Event> tallies) async {
    final now = DateTime.now();
    for (final e in tallies) {
      final period = ResetPeriodX.fromDb(e.resetPeriod);
      if (period == ResetPeriod.never) continue;
      final ref = e.lastResetAt ?? e.createdAt;
      final due = switch (period) {
        ResetPeriod.daily   => !_sameDay(ref, now),
        ResetPeriod.weekly  => now.difference(ref).inDays >= 7,
        ResetPeriod.monthly => now.month != ref.month || now.year != ref.year,
        ResetPeriod.yearly  => now.year != ref.year,
        ResetPeriod.never   => false,
      };
      if (due) await resetTally(e.id);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    EventRepository(ref.watch(appDatabaseProvider));