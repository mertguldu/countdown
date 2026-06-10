import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';
import '../widgets/event_list_item.dart';

// ── Edit tab ──────────────────────────────────────────────────────────────────
// Public so HomeScreen can use it for the floating tab bar.

enum EditTab { active, finished }

extension EditTabX on EditTab {
  String get label => switch (this) {
        EditTab.active   => 'Active',
        EditTab.finished => 'Finished',
      };
}

// ── EventsScreen ──────────────────────────────────────────────────────────────

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({
    super.key,
    this.isEditing = false,
    this.editTab   = EditTab.active,
  });

  final bool isEditing;
  final EditTab editTab;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {

  // ── Edit-mode local state ─────────────────────────────────────────────────

  List<({String category, List<Event> events})> _groups = [];
  List<Event> _allEvents      = [];
  List<Event> _finishedEvents = [];
  bool _editInitialized = false;
  ProviderSubscription<AsyncValue<List<Event>>>? _flatSub;

  // ── Life-cycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _scheduleEditInit();
  }

  @override
  void didUpdateWidget(EventsScreen old) {
    super.didUpdateWidget(old);
    if (widget.isEditing && !old.isEditing) _scheduleEditInit();
    if (!widget.isEditing && old.isEditing) _tearDownEditMode();
  }

  @override
  void dispose() {
    _flatSub?.close();
    super.dispose();
  }

  // ── Edit init ─────────────────────────────────────────────────────────────

  void _scheduleEditInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flatSub?.close();
      _flatSub = ref.listenManual(
        flatEventsProvider,
        (_, next) {
          if (_editInitialized || !mounted) return;
          next.whenData((events) {
            setState(() {
              _initFromEvents(events);
              _editInitialized = true;
            });
            _flatSub?.close();
            _flatSub = null;
          });
        },
        fireImmediately: true,
      );
    });
  }

  void _tearDownEditMode() {
    _flatSub?.close();
    _flatSub = null;
    setState(() {
      _editInitialized = false;
      _groups          = [];
      _allEvents       = [];
      _finishedEvents  = [];
    });
  }

  void _initFromEvents(List<Event> events) {
    _allEvents = events;

    final now      = DateTime.now();
    final activeMap = <String, List<Event>>{};
    final finished  = <Event>[];

    for (final e in events) {
      if (e.targetDate.isAfter(now)) {
        (activeMap[e.category] ??= []).add(e);
      } else {
        finished.add(e);
      }
    }

    _groups         = activeMap.entries
        .map((e) => (category: e.key, events: [...e.value]))
        .toList();
    _finishedEvents = finished;
  }

  // ── Group reorder ─────────────────────────────────────────────────────────

  void _moveGroupUp(int gi) {
    if (gi == 0) return;
    HapticFeedback.selectionClick();
    final list = [..._groups];
    final g    = list.removeAt(gi);
    list.insert(gi - 1, g);
    setState(() => _groups = list);
    _saveOrder(list);
  }

  void _moveGroupDown(int gi) {
    if (gi >= _groups.length - 1) return;
    HapticFeedback.selectionClick();
    final list = [..._groups];
    final g    = list.removeAt(gi);
    list.insert(gi + 1, g);
    setState(() => _groups = list);
    _saveOrder(list);
  }

  // ── Item reorder ──────────────────────────────────────────────────────────

  void _reorderItem(int gi, int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx--;
    final events = [..._groups[gi].events];
    final event  = events.removeAt(oldIdx);
    events.insert(newIdx, event);
    final list = [..._groups];
    list[gi] = (category: _groups[gi].category, events: events);
    setState(() => _groups = list);
    _saveOrder(list);
  }

  // ── Persist order ─────────────────────────────────────────────────────────

  void _saveOrder(List<({String category, List<Event> events})> groups) {
    final now             = DateTime.now();
    final pastByCategory  = <String, List<Event>>{};
    for (final e in _allEvents) {
      if (!e.targetDate.isAfter(now)) {
        (pastByCategory[e.category] ??= []).add(e);
      }
    }

    final updates = <({int id, int sortOrder})>[];
    var order = 0;

    for (final g in groups) {
      for (final e in g.events) {
        updates.add((id: e.id, sortOrder: order++));
      }
      for (final e in pastByCategory[g.category] ?? const []) {
        updates.add((id: e.id, sortOrder: order++));
      }
    }

    final covered = groups.map((g) => g.category).toSet();
    for (final entry in pastByCategory.entries) {
      if (!covered.contains(entry.key)) {
        for (final e in entry.value) {
          updates.add((id: e.id, sortOrder: order++));
        }
      }
    }

    ref.read(eventRepositoryProvider).reorder(updates);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _onDelete(Event event) async {
    final repo = ref.read(eventRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove event?'),
        content: Text('"${event.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _allEvents      = _allEvents.where((e) => e.id != event.id).toList();
      _finishedEvents = _finishedEvents.where((e) => e.id != event.id).toList();
      _groups         = _groups
          .map((g) => (
                category: g.category,
                events: g.events.where((e) => e.id != event.id).toList(),
              ))
          .where((g) => g.events.isNotEmpty)
          .toList();
    });

    try {
      await NotificationService.cancel(event.id);
      await repo.deleteEvent(event.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    // ── Edit mode ────────────────────────────────────────────────────────────
    if (widget.isEditing) {
      if (!_editInitialized) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: widget.editTab == EditTab.finished
            ? _FinishedEditView(
                key:      const ValueKey('finished_view'),
                events:   _finishedEvents,
                onDelete: _onDelete,
              )
            : (_groups.isEmpty
                ? const _EmptyState(key: ValueKey('empty_active'))
                : _GroupedEditView(
                    key:             const ValueKey('active_view'),
                    groups:          _groups,
                    onMoveGroupUp:   _moveGroupUp,
                    onMoveGroupDown: _moveGroupDown,
                    onReorderItem:   _reorderItem,
                    onDelete:        _onDelete,
                  )),
      );
    }

    // ── Date sort view ───────────────────────────────────────────────────────
    final filter = ref.watch(eventFilterProvider);
    if (filter == EventFilter.byDateAsc || filter == EventFilter.byDateDesc) {
      final byDateAsync = ref.watch(byDateEventsProvider);
      return byDateAsync.when(
        data: (events) => events.isEmpty
            ? const _EmptyState()
            : _FlatDateList(events: events),
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => _ErrorState(error: e),
      );
    }

    // ── Normal grouped view ──────────────────────────────────────────────────
    final groupedAsync = ref.watch(groupedEventsProvider);
    return groupedAsync.when(
      data:    (grouped) => _EventList(grouped: grouped),
      loading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => _ErrorState(error: e),
    );
  }
}

// ── _GroupedEditView ──────────────────────────────────────────────────────────

class _GroupedEditView extends StatelessWidget {
  const _GroupedEditView({
    super.key,
    required this.groups,
    required this.onMoveGroupUp,
    required this.onMoveGroupDown,
    required this.onReorderItem,
    required this.onDelete,
  });

  final List<({String category, List<Event> events})> groups;
  final void Function(int gi) onMoveGroupUp;
  final void Function(int gi) onMoveGroupDown;
  final void Function(int gi, int oldIdx, int newIdx) onReorderItem;
  final Future<void> Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];

    for (int gi = 0; gi < groups.length; gi++) {
      final capturedGi = gi;
      final g          = groups[gi];

      slivers.add(SliverToBoxAdapter(
        child: _EditGroupHeader(
          key:         ValueKey('hdr_${g.category}'),
          category:    g.category,
          canMoveUp:   capturedGi > 0,
          canMoveDown: capturedGi < groups.length - 1,
          onMoveUp:    () => onMoveGroupUp(capturedGi),
          onMoveDown:  () => onMoveGroupDown(capturedGi),
        ),
      ));

      slivers.add(SliverReorderableList(
        key:       ValueKey('srl_${g.category}'),
        itemCount: g.events.length,
        onReorder: (o, n) => onReorderItem(capturedGi, o, n),
        itemBuilder: (context, ii) {
          final event = g.events[ii];
          return ReorderableDelayedDragStartListener(
            key:   ValueKey(event.id),
            index: ii,
            child: Material(
              color: Colors.transparent,
              child: EventListItem(
                event:       event,
                isEditing:   true,
                isDraggable: true,    // ← active items show drag handle
                onDelete:    () => onDelete(event),
              ),
            ),
          );
        },
      ));

      if (capturedGi < groups.length - 1) {
        slivers.add(const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _RowDivider(),
          ),
        ));
      }
    }

    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 100)));
    return CustomScrollView(slivers: slivers);
  }
}

// ── _EditGroupHeader ──────────────────────────────────────────────────────────

class _EditGroupHeader extends StatelessWidget {
  const _EditGroupHeader({
    super.key,
    required this.category,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String category;
  final bool canMoveUp, canMoveDown;
  final VoidCallback onMoveUp, onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted     = theme.textTheme.bodyMedium?.color ??
        onSurface.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 6),
      child: Row(
        children: [
          Text(
            category.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _GroupMoveButton(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: canMoveUp, onTap: onMoveUp,
          ),
          _GroupMoveButton(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: canMoveDown, onTap: onMoveDown,
          ),
        ],
      ),
    );
  }
}

class _GroupMoveButton extends StatelessWidget {
  const _GroupMoveButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          icon, size: 22,
          color: enabled ? onSurface : onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

// ── _FinishedEditView ─────────────────────────────────────────────────────────
//
// Shows past events grouped by category. Delete only — no drag reordering.
// EventListItem with isEditing:true, isDraggable:false shows the delete button
// on the left and the "Finished" countdown label on the right.

class _FinishedEditView extends StatelessWidget {
  const _FinishedEditView({
    super.key,
    required this.events,
    required this.onDelete,
  });

  final List<Event> events;
  final Future<void> Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      final muted = Theme.of(context).textTheme.bodyMedium?.color;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: muted?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No finished events',
              style: AppTextStyles.bodyMedium.copyWith(color: muted),
            ),
          ],
        ),
      );
    }

    // Group by category, preserving encounter order (events come
    // from _allEvents which is in sortOrder order).
    final map = <String, List<Event>>{};
    for (final e in events) {
      (map[e.category] ??= []).add(e);
    }

    final slivers = <Widget>[];
    var first = true;

    for (final entry in map.entries) {
      if (!first) {
        slivers.add(const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _RowDivider(),
          ),
        ));
      }
      first = false;

      slivers.add(SliverToBoxAdapter(
        child: _CategoryHeader(entry.key),
      ));

      slivers.add(SliverList.builder(
        itemCount: entry.value.length,
        itemBuilder: (context, ii) {
          final event = entry.value[ii];
          return EventListItem(
            key:       ValueKey('fin_${event.id}'),
            event:     event,
            isEditing: true,
            // isDraggable defaults to false → shows countdown ("Finished")
            onDelete:  () => onDelete(event),
          );
        },
      ));
    }

    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 100)));
    return CustomScrollView(slivers: slivers);
  }
}

// ── _FlatDateList ─────────────────────────────────────────────────────────────

class _FlatDateList extends StatelessWidget {
  const _FlatDateList({required this.events});
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: events.length,
      separatorBuilder: (_, __) => const _RowDivider(),
      itemBuilder: (context, index) => EventListItem(
        event: events[index],
        onTap: () {},
      ),
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
      for (final event in entry.value) items.add(_EventItem(event));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: items.length,
      separatorBuilder: (_, index) {
        final current = items[index];
        final next = index + 1 < items.length ? items[index + 1] : null;
        if (current is _EventItem &&
            (next is _EventItem || next is _SectionItem)) {
          return const _RowDivider();
        }
        return const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        return switch (items[index]) {
          _SectionItem(:final category) => _CategoryHeader(category),
          _EventItem(:final event) => EventListItem(
              event: event,
              onTap: () {},
            ),
        };
      },
    );
  }
}

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
          color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w600,
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
      height: 1, thickness: 0.5,
      color: muted?.withValues(alpha: 0.2),
    );
  }
}

// ── Empty / error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

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