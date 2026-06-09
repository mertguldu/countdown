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

  void select(EventFilter filter) => state = filter;
}

// ── Grouped events stream (upcoming / past / all) ─────────────────────────────

final groupedEventsProvider =
    StreamProvider.autoDispose<Map<String, List<Event>>>((ref) {
  final filter = ref.watch(eventFilterProvider);
  final repo   = ref.watch(eventRepositoryProvider);

  return repo.watchFiltered(filter).map((events) {
    final grouped = <String, List<Event>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.category, () => []).add(event);
    }
    return grouped;
  });
});

// ── Flat events stream — edit mode init ───────────────────────────────────────
// Always uses EventFilter.all (sortOrder order). Only subscribed while
// EventsScreen is snapshotting its initial edit-mode state.

final flatEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchFiltered(EventFilter.all);
});

// ── Flat chronological stream — Date ↑ / Date ↓ view ─────────────────────────
// Reacts automatically when the filter toggles between byDateAsc / byDateDesc.

final byDateEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final filter = ref.watch(eventFilterProvider);
  final repo   = ref.watch(eventRepositoryProvider);
  return repo.watchFiltered(filter);
});