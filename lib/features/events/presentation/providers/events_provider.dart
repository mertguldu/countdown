import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';

part 'events_provider.g.dart';

// ── Filter state ──────────────────────────────────────────────────────────────
// riverpod_generator ^3.0 strips the "Notifier" suffix from the generated
// provider name. EventFilterNotifier → eventFilterProvider (not
// eventFilterNotifierProvider). Use eventFilterProvider everywhere.

@riverpod
class EventFilterNotifier extends _$EventFilterNotifier {
  @override
  EventFilter build() => EventFilter.upcoming;

  void select(EventFilter filter) => state = filter;
}

// ── Grouped events stream ─────────────────────────────────────────────────────
// Manually defined — riverpod_generator cannot resolve the import path for
// Drift-generated types (Event lives in database.g.dart, a `part` file).

final groupedEventsProvider =
    StreamProvider.autoDispose<Map<String, List<Event>>>((ref) {
  final filter = ref.watch(eventFilterProvider); // ← eventFilterProvider, not eventFilterNotifierProvider
  final repo = ref.watch(eventRepositoryProvider);

  return repo.watchFiltered(filter).map((events) {
    final grouped = <String, List<Event>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.category, () => []).add(event);
    }
    return grouped;
  });
});