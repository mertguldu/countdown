import 'package:drift/drift.dart';

// ── Filter state enum ─────────────────────────────────────────────────────────
// Used by EventFilterNotifier and EventRepository to drive the list query.

enum EventFilter { upcoming, past, all }

// ── Drift table definition ────────────────────────────────────────────────────
// Add this class to @DriftDatabase(tables: [...]) in database.dart and
// uncomment the matching export in schemas.dart.
//
// Generated artefacts (after `dart run build_runner build`):
//   - Event          — immutable row data class
//   - EventsCompanion — mutable companion for inserts / updates

@DataClassName('Event')
class Events extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Display name shown on the event card, e.g. "Italy Trip".
  TextColumn get title => text()();

  /// Optional one-liner shown below the title, e.g. "Amalfi coast".
  TextColumn get subtitle => text().nullable()();

  /// Category label used as the section header, e.g. "TRIPS".
  /// Stored in display-case; uppercasing happens in the UI layer.
  TextColumn get category => text()();

  /// The moment this event is counting down to (or counting from).
  DateTimeColumn get targetDate => dateTime()();

  /// ARGB colour packed as an int — used to tint the thumbnail tile.
  /// Default is AppColors.primary.
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF5C6BC0))();

  /// Manual sort position used in the "All" view drag-reorder.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Row creation timestamp.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}