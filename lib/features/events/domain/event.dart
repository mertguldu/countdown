import 'package:drift/drift.dart';

// ── Filter state enum ─────────────────────────────────────────────────────────

enum EventFilter { upcoming, past, all, byDateAsc, byDateDesc }

// ── Event type ────────────────────────────────────────────────────────────────

enum EventType { countdown, countup, tally }

extension EventTypeX on EventType {
  static EventType fromDb(String v) =>
      EventType.values.firstWhere((e) => e.name == v,
          orElse: () => EventType.countdown);
}

// ── Reset period (tally auto-reset) ──────────────────────────────────────────

enum ResetPeriod { never, daily, weekly, monthly, yearly }

extension ResetPeriodX on ResetPeriod {
  /// Short label shown as the tally item subtitle.
  String get displayLabel => switch (this) {
        ResetPeriod.never   => 'Never resets',
        ResetPeriod.daily   => 'Resets daily',
        ResetPeriod.weekly  => 'Resets weekly',
        ResetPeriod.monthly => 'Resets monthly',
        ResetPeriod.yearly  => 'Resets yearly',
      };

  /// Label used in the creation-flow picker.
  String get pickerLabel => switch (this) {
        ResetPeriod.never   => 'Never',
        ResetPeriod.daily   => 'Daily',
        ResetPeriod.weekly  => 'Weekly',
        ResetPeriod.monthly => 'Monthly',
        ResetPeriod.yearly  => 'Yearly',
      };

  static ResetPeriod fromDb(String? v) => v == null
      ? ResetPeriod.never
      : ResetPeriod.values.firstWhere((e) => e.name == v,
            orElse: () => ResetPeriod.never);
}

// ── Repeat period (countdown / count-up recurrence) ──────────────────────────

enum RepeatOption { never, daily, weekly, biweekly, monthly, yearly }

extension RepeatOptionX on RepeatOption {
  String get label => switch (this) {
        RepeatOption.never    => 'Never',
        RepeatOption.daily    => 'Daily',
        RepeatOption.weekly   => 'Weekly',
        RepeatOption.biweekly => 'Every 2 weeks',
        RepeatOption.monthly  => 'Monthly',
        RepeatOption.yearly   => 'Yearly',
      };

  static RepeatOption fromDb(String? v) => v == null
      ? RepeatOption.never
      : RepeatOption.values.firstWhere((e) => e.name == v,
            orElse: () => RepeatOption.never);
}

// ── Drift table definition ────────────────────────────────────────────────────

@DataClassName('Event')
class Events extends Table {
  IntColumn get id         => integer().autoIncrement()();
  TextColumn get title     => text()();
  TextColumn get subtitle  => text().nullable()();
  TextColumn get category  => text()();

  /// 'countdown' | 'countup' | 'tally'
  TextColumn get eventType =>
      text().withDefault(const Constant('countdown'))();

  /// Null only for tally items.
  DateTimeColumn get targetDate => dateTime().nullable()();

  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF5C6BC0))();
  TextColumn get photoPath  => text().nullable()();
  IntColumn get sortOrder   => integer().withDefault(const Constant(0))();

  // ── Countdown / count-up only ─────────────────────────────────────────────
  /// 'daily' | 'weekly' | 'biweekly' | 'monthly' | 'yearly'
  /// Null / absent means RepeatOption.never — we never store the string 'never'.
  TextColumn get repeatPeriod => text().nullable()();

  // ── Reminder (countdown / count-up only) ─────────────────────────────────
  /// 'oneWeek' | 'oneDay' | 'dayOf' | 'custom' | null
  /// Null means the per-type default has never been overridden.
  TextColumn get reminderType => text().nullable()();

  /// Total duration of a custom reminder, stored as seconds.
  /// Only meaningful when reminderType == 'custom'.
  IntColumn get reminderCustomSecs => integer().nullable()();

  // ── Tally-only ───────────────────────────────────────────────────────────
  IntColumn    get tallyCount  => integer().withDefault(const Constant(0))();
  TextColumn   get resetPeriod => text().nullable()();
  DateTimeColumn get lastResetAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ── Count-up filter state enum ─────────────────────────────────────────────────

enum CountUpFilter { running, upcoming, all }

extension CountUpFilterX on CountUpFilter {
  String get label => switch (this) {
    CountUpFilter.running  => 'Running',
    CountUpFilter.upcoming => 'Upcoming',
    CountUpFilter.all      => 'All',
  };

  String get emptyMessage => switch (this) {
    CountUpFilter.running  => 'Nothing running yet.',
    CountUpFilter.upcoming => 'No upcoming count-up events.',
    CountUpFilter.all      => 'No count-up events yet.\nTap + to add one.',
  };
}

// ── Tally view mode ───────────────────────────────────────────────────────────

enum TallyViewMode { category, all }

extension TallyViewModeX on TallyViewMode {
  String get label => switch (this) {
    TallyViewMode.category => 'Category',
    TallyViewMode.all      => 'All',
  };
}