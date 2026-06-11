import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

part 'events_provider.g.dart';

// ── Filter state ──────────────────────────────────────────────────────────────
// @riverpod on EventFilterNotifier → generator emits `eventFilterProvider`
// (strips the "Notifier" suffix). Matches the existing .g.dart.

@riverpod
class EventFilterNotifier extends _$EventFilterNotifier {
  @override
  EventFilter build() => EventFilter.upcoming;

  void select(EventFilter f) => state = f;
}

// ── Countdown events (Events tab) ─────────────────────────────────────────────

final groupedEventsProvider =
    StreamProvider.autoDispose<Map<String, List<Event>>>((ref) {
  final filter = ref.watch(eventFilterProvider);
  final repo   = ref.watch(eventRepositoryProvider);
  return repo.watchFiltered(filter).map((events) {
    final grouped = <String, List<Event>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.category, () => []).add(e);
    }
    return grouped;
  });
});

/// Flat countdown stream — edit-mode initialisation.
final flatEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref.watch(eventRepositoryProvider).watchFiltered(EventFilter.all));

/// Flat chronological stream — Date ↑ / ↓ view.
final byDateEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref
        .watch(eventRepositoryProvider)
        .watchFiltered(ref.watch(eventFilterProvider)));

// ── Countup events (Count Up tab) ─────────────────────────────────────────────

final groupedCountupProvider =
    StreamProvider.autoDispose<Map<String, List<Event>>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchByType(EventType.countup).map((events) {
    final grouped = <String, List<Event>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.category, () => []).add(e);
    }
    return grouped;
  });
});

final flatCountupProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref.watch(eventRepositoryProvider).watchByType(EventType.countup));

// ── Tally items (Tally tab) ───────────────────────────────────────────────────

final groupedTallyProvider =
    StreamProvider.autoDispose<Map<String, List<Event>>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchByType(EventType.tally).map((events) {
    final grouped = <String, List<Event>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.category, () => []).add(e);
    }
    return grouped;
  });
});

final flatTallyProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref.watch(eventRepositoryProvider).watchByType(EventType.tally));

// ── Count-up filter state ─────────────────────────────────────────────────────

@riverpod
class CountUpFilterNotifier extends _$CountUpFilterNotifier {
  @override
  CountUpFilter build() => CountUpFilter.running;

  void select(CountUpFilter f) => state = f;
}

/// Grouped count-up events, filtered by running / upcoming / all.
final groupedCountupFilteredProvider =
    StreamProvider.autoDispose<Map<String, List<Event>>>((ref) {
  final filter = ref.watch(countUpFilterProvider);
  final repo   = ref.watch(eventRepositoryProvider);
  return repo.watchCountUpFiltered(filter).map((events) {
    final grouped = <String, List<Event>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.category, () => []).add(e);
    }
    return grouped;
  });
});

// ── Tally view mode ───────────────────────────────────────────────────────────

@riverpod
class TallyViewModeNotifier extends _$TallyViewModeNotifier {
  @override
  TallyViewMode build() => TallyViewMode.category;

  void select(TallyViewMode m) => state = m;
}

/// Tally events ordered by createdAt DESC — used for the All flat view.
final flatTallyAllProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref.watch(eventRepositoryProvider).watchTallyAll());