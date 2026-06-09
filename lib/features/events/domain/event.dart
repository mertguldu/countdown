import 'package:drift/drift.dart';

// ── Filter state enum ─────────────────────────────────────────────────────────

enum EventFilter { upcoming, past, all, byDateAsc, byDateDesc }

// ── Drift table definition ────────────────────────────────────────────────────

@DataClassName('Event')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get category => text()();
  DateTimeColumn get targetDate => dateTime()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF5C6BC0))();
  TextColumn get photoPath => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}