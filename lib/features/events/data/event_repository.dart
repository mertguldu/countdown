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
    Expression<bool> isCountdown(Events t) =>
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

  /// Count-up events filtered by running / upcoming / all status.
  Stream<List<Event>> watchCountUpFiltered(CountUpFilter filter) {
    final now      = DateTime.now();
    final q        = _db.select(_db.events);
    Expression<bool> isCountup(Events t) => t.eventType.equals(EventType.countup.name);

    switch (filter) {
      case CountUpFilter.running:
        q
          ..where((t) => isCountup(t) & t.targetDate.isSmallerOrEqualValue(now))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.targetDate),
          ]);
      case CountUpFilter.upcoming:
        q
          ..where((t) => isCountup(t) & t.targetDate.isBiggerThanValue(now))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.targetDate),
          ]);
      case CountUpFilter.all:
        q
          ..where(isCountup)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.targetDate),
          ]);
    }
    return q.watch();
  }

  /// Tally events ordered by createdAt DESC — newest first (All view).
  Stream<List<Event>> watchTallyAll() =>
      (_db.select(_db.events)
            ..where((t) => t.eventType.equals(EventType.tally.name))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
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
      final baseline = e.lastResetAt ?? e.createdAt;
      final due = switch (period) {
        ResetPeriod.daily   => !_sameDay(baseline, now),
        ResetPeriod.weekly  => now.difference(baseline).inDays >= 7,
        ResetPeriod.monthly => now.month != baseline.month || now.year != baseline.year,
        ResetPeriod.yearly  => now.year != baseline.year,
        ResetPeriod.never   => false,
      };
      if (due) await resetTally(e.id);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Repeat ────────────────────────────────────────────────────────────────

  /// Returns all countdown and count-up events that have a repeat period set.
  /// Tally events are excluded — they use [processAutoResets] instead.
  Future<List<Event>> fetchAllRepeatable() =>
      (_db.select(_db.events)
            ..where((t) =>
                t.eventType.isNotIn([EventType.tally.name]) &
                t.repeatPeriod.isNotNull()))
          .get();

  /// Advances any repeating events whose [targetDate] is now in the past.
  ///
  /// The date is advanced from the *stored* value (not from "now") so that
  /// the original cadence is preserved even if the app hasn't been opened
  /// for multiple cycles. Returns enough info for the caller to reschedule
  /// notifications without needing to re-query the database.
  Future<List<({int id, String title, DateTime newDate})>> processRepeats(
      List<Event> events) async {
    final now     = DateTime.now();
    final results = <({int id, String title, DateTime newDate})>[];

    for (final e in events) {
      final td = e.targetDate;
      if (td == null || td.isAfter(now)) continue;

      final repeat = RepeatOptionX.fromDb(e.repeatPeriod);
      if (repeat == RepeatOption.never) continue;

      // Advance from the stored date one period at a time until we are in
      // the future. This handles the case where the app was closed for
      // multiple repeat cycles (e.g. a daily event missed for three days).
      DateTime next = td;
      while (!next.isAfter(now)) {
        next = _advanceDate(next, repeat);
      }

      await (_db.update(_db.events)..where((t) => t.id.equals(e.id)))
          .write(EventsCompanion(targetDate: Value(next)));

      results.add((id: e.id, title: e.title, newDate: next));
    }

    return results;
  }

  DateTime _advanceDate(DateTime from, RepeatOption repeat) => switch (repeat) {
    RepeatOption.never    => from,
    RepeatOption.daily    => from.add(const Duration(days: 1)),
    RepeatOption.weekly   => from.add(const Duration(days: 7)),
    RepeatOption.biweekly => from.add(const Duration(days: 14)),
    RepeatOption.monthly  => _addMonth(from),
    RepeatOption.yearly   =>
        DateTime(from.year + 1, from.month, from.day, from.hour, from.minute),
  };

  /// Adds exactly one calendar month, clamping to the last valid day if the
  /// target month is shorter (e.g. Jan 31 → Feb 28/29, not Mar 2/3).
  DateTime _addMonth(DateTime from) {
    var year  = from.year;
    var month = from.month + 1;
    if (month > 12) { month = 1; year++; }
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
        year, month, from.day.clamp(1, lastDay), from.hour, from.minute);
  }
}

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    EventRepository(ref.watch(appDatabaseProvider));