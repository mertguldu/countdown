import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/events_provider.dart';
import '../widgets/event_list_item.dart';
import '../widgets/filter_pills.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFilterProvider);         // ← eventFilterProvider
    final groupedAsync = ref.watch(groupedEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: FilterPills(
            selected: filter,
            onSelect: ref.read(eventFilterProvider.notifier).select, // ← eventFilterProvider
          ),
        ),
        Expanded(
          child: groupedAsync.when(
            data: (grouped) => _EventList(grouped: grouped),
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => _ErrorState(error: e),
          ),
        ),
      ],
    );
  }
}

// ── _EventList ────────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  const _EventList({required this.grouped});

  final Map<String, List<Event>> grouped;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) return const _EmptyState();

    final items = <_ListItem>[];
    for (final entry in grouped.entries) {
      items.add(_SectionItem(entry.key));
      for (final event in entry.value) {
        items.add(_EventItem(event));
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: items.length,
      separatorBuilder: (_, index) {
        final current = items[index];
        final next = index + 1 < items.length ? items[index + 1] : null;
        if (current is _EventItem && (next is _EventItem || next is _SectionItem)) {
          return const _RowDivider();
        }
        return const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        return switch (items[index]) {
          _SectionItem(:final category) => _CategoryHeader(category),
          _EventItem(:final event) => EventListItem(
              event: event,
              onTap: () {
                // TODO: context.push(AppRoutes.eventDetailPath(event.id.toString()))
              },
            ),
        };
      },
    );
  }
}

// ── List item sealed types ────────────────────────────────────────────────────

sealed class _ListItem {}

final class _SectionItem extends _ListItem {
  _SectionItem(this.category);
  final String category;
}

final class _EventItem extends _ListItem {
  _EventItem(this.event);
  final Event event;
}

// ── Section header ────────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.category);
  final String category;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        category.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: muted,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Divider(
      height: 1,
      thickness: 0.5,
      color: muted?.withValues(alpha: 0.2),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Center(
      child: Text(
        'No events yet.\nTap + to add one.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(color: muted),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Something went wrong.\n$error',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}