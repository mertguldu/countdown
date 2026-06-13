import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

part 'events_provider.g.dart';

// ── Filter state ──────────────────────────────────────────────────────────────

@riverpod
class EventFilterNotifier extends _$EventFilterNotifier {
  @override
  EventFilter build() => EventFilter.upcoming;

  void select(EventFilter f) => state = f;
}

// ── Single event (detail sheet) ───────────────────────────────────────────────

/// Watches one event by ID. Emits null when deleted.
/// autoDispose + family ensures the DB subscription is released when the
/// detail sheet closes.
final eventByIdProvider =
    StreamProvider.autoDispose.family<Event?, int>((ref, id) =>
        ref.watch(eventRepositoryProvider).watchById(id));

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

final flatEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref.watch(eventRepositoryProvider).watchFiltered(EventFilter.all));

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

final flatTallyAllProvider = StreamProvider.autoDispose<List<Event>>((ref) =>
    ref.watch(eventRepositoryProvider).watchTallyAll());