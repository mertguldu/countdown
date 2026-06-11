import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';
import '../widgets/event_list_item.dart';

enum EditTab { active, finished }

/// Shared screen for both countdown (Events tab) and countup (Count Up tab).
/// [eventTypeFilter] switches providers, display widgets, and edit-mode logic.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({
    super.key,
    this.isEditing       = false,
    this.editTab         = EditTab.active,
    this.eventTypeFilter = EventType.countdown,
  });

  final bool      isEditing;
  final EditTab   editTab;
  final EventType eventTypeFilter;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  // ── Edit-mode local state ─────────────────────────────────────────────────
  List<({String category, List<Event> events})> _groups         = [];
  List<Event>                                   _finishedEvents  = [];
  bool                                          _editInitialized = false;
  ProviderSubscription<AsyncValue<List<Event>>>? _flatSub;

  bool get _isCountup => widget.eventTypeFilter == EventType.countup;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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
      final provider = _isCountup ? flatCountupProvider : flatEventsProvider;
      _flatSub = ref.listenManual(
        provider,
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
      _finishedEvents  = [];
    });
  }

  void _initFromEvents(List<Event> events) {
    if (_isCountup) {
      // Countup: no active/finished split — just group by category.
      final map = <String, List<Event>>{};
      for (final e in events) {
        (map[e.category] ??= []).add(e);
      }
      _groups         = map.entries
          .map((e) => (category: e.key, events: [...e.value]))
          .toList();
      _finishedEvents = [];
      return;
    }

    // Countdown: split into active (future date) and finished (past date).
    final now       = DateTime.now();
    final activeMap = <String, List<Event>>{};
    final finished  = <Event>[];
    for (final e in events) {
      final td = e.targetDate;
      if (td != null && td.isAfter(now)) {
        (activeMap[e.category] ??= []).add(e);
      } else {
        finished.add(e);
      }
    }
    _groups = activeMap.entries
        .map((e) => (category: e.key, events: [...e.value]))
        .toList();
    _finishedEvents = finished;
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  void _moveGroupUp(int gi) {
    if (gi == 0) return;
    HapticFeedback.selectionClick();
    final list = [..._groups];
    list.insert(gi - 1, list.removeAt(gi));
    setState(() => _groups = list);
    _saveOrder(list);
  }

  void _moveGroupDown(int gi) {
    if (gi >= _groups.length - 1) return;
    HapticFeedback.selectionClick();
    final list = [..._groups];
    list.insert(gi + 1, list.removeAt(gi));
    setState(() => _groups = list);
    _saveOrder(list);
  }

  void _reorderItem(int gi, int old, int neo) {
    if (neo > old) neo--;
    final evts = [..._groups[gi].events];
    evts.insert(neo, evts.removeAt(old));
    final list = [..._groups];
    list[gi] = (category: _groups[gi].category, events: evts);
    setState(() => _groups = list);
    _saveOrder(list);
  }

  void _saveOrder(List<({String category, List<Event> events})> groups) {
    final updates = <({int id, int sortOrder})>[];
    var order = 0;

    if (_isCountup) {
      for (final g in groups) {
        for (final e in g.events) {
          updates.add((id: e.id, sortOrder: order++));
        }
      }
      ref.read(eventRepositoryProvider).reorder(updates);
      return;
    }

    // Countdown: active events first, then finished (preserve their order).
    for (final g in groups) {
      for (final e in g.events) {
        updates.add((id: e.id, sortOrder: order++));
      }
    }
    for (final e in _finishedEvents) {
      updates.add((id: e.id, sortOrder: order++));
    }
    ref.read(eventRepositoryProvider).reorder(updates);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _onDelete(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${event.title}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _groups = _groups
          .map((g) => (
                category: g.category,
                events: g.events.where((e) => e.id != event.id).toList(),
              ))
          .where((g) => g.events.isNotEmpty)
          .toList();
      _finishedEvents =
          _finishedEvents.where((e) => e.id != event.id).toList();
    });

    await ref.read(eventRepositoryProvider).deleteEvent(event.id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    // ── Edit mode ────────────────────────────────────────────────────────────
    if (widget.isEditing) {
      if (!_editInitialized) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      // Countup: no active/finished tabs — just one grouped edit view.
      if (_isCountup) {
        return _groups.isEmpty
            ? const _EmptyState(
                message: 'No count-up events yet.\nTap + to add one.')
            : _GroupedEditView(
                key:             const ValueKey('countup_edit'),
                groups:          _groups,
                eventType:       EventType.countup,
                onMoveGroupUp:   _moveGroupUp,
                onMoveGroupDown: _moveGroupDown,
                onReorderItem:   _reorderItem,
                onDelete:        _onDelete,
              );
      }

      // Countdown: AnimatedSwitcher between Active and Finished tabs.
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
                ? const _EmptyState(
                    key: ValueKey('empty_active'),
                    message: 'No upcoming events.',
                  )
                : _GroupedEditView(
                    key:             const ValueKey('active_edit'),
                    groups:          _groups,
                    eventType:       EventType.countdown,
                    onMoveGroupUp:   _moveGroupUp,
                    onMoveGroupDown: _moveGroupDown,
                    onReorderItem:   _reorderItem,
                    onDelete:        _onDelete,
                  )),
      );
    }

    // ── Normal mode ──────────────────────────────────────────────────────────

    // Countup — grouped, filtered by Running / Upcoming / All.
    if (_isCountup) {
      final countUpFilter = ref.watch(countUpFilterProvider);
      return ref.watch(groupedCountupFilteredProvider).when(
        data: (grouped) => grouped.isEmpty
            ? _EmptyState(message: countUpFilter.emptyMessage)
            : _EventList(grouped: grouped, eventType: EventType.countup),
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => _ErrorState('$e'),
      );
    }

    // Countdown — grouped, filtered by Upcoming / Past / All.
    return ref.watch(groupedEventsProvider).when(
      data: (grouped) => grouped.isEmpty
          ? const _EmptyState(message: 'No events yet.\nTap + to add one.')
          : _EventList(grouped: grouped, eventType: EventType.countdown),
      loading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => _ErrorState('$e'),
    );
  }
}

// ── _EventList ────────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  const _EventList({
    required this.grouped,
    this.eventType = EventType.countdown,
  });

  final Map<String, List<Event>> grouped;
  final EventType                eventType;

  @override
  Widget build(BuildContext context) {
    final entries = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final cat    = entries[i].key;
        final events = entries[i].value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryHeader(cat),
            for (int j = 0; j < events.length; j++) ...[
              EventListItem(
                event:     events[j],
                eventType: eventType,
                onTap:     () {},
              ),
              if (j < events.length - 1) const _Divider(),
            ],
          ],
        );
      },
    );
  }
}

// ── _GroupedEditView ──────────────────────────────────────────────────────────

class _GroupedEditView extends StatelessWidget {
  const _GroupedEditView({
    super.key,
    required this.groups,
    required this.eventType,
    required this.onMoveGroupUp,
    required this.onMoveGroupDown,
    required this.onReorderItem,
    required this.onDelete,
  });

  final List<({String category, List<Event> events})> groups;
  final EventType                                     eventType;
  final void Function(int)                            onMoveGroupUp;
  final void Function(int)                            onMoveGroupDown;
  final void Function(int, int, int)                  onReorderItem;
  final Future<void> Function(Event)                  onDelete;

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];
    for (int gi = 0; gi < groups.length; gi++) {
      final capturedGi = gi;
      final g = groups[gi];

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
        itemBuilder: (ctx, ii) {
          final event = g.events[ii];
          return ReorderableDelayedDragStartListener(
            key:   ValueKey(event.id),
            index: ii,
            child: Material(
              color: Colors.transparent,
              child: EventListItem(
                event:       event,
                eventType:   eventType,
                isEditing:   true,
                isDraggable: true,
                onDelete:    () => onDelete(event),
              ),
            ),
          );
        },
      ));

      if (capturedGi < groups.length - 1) {
        slivers.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const _Divider(),
          ),
        ));
      }
    }
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 120)));
    return CustomScrollView(slivers: slivers);
  }
}

// ── _FinishedEditView ─────────────────────────────────────────────────────────

class _FinishedEditView extends StatelessWidget {
  const _FinishedEditView({
    super.key,
    required this.events,
    required this.onDelete,
  });

  final List<Event>                  events;
  final Future<void> Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyState(message: 'No finished events.');
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: events.length,
      separatorBuilder: (_, __) => const _Divider(),
      itemBuilder: (ctx, i) => EventListItem(
        event:     events[i],
        isEditing: true,
        onDelete:  () => onDelete(events[i]),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _EditGroupHeader extends StatelessWidget {
  const _EditGroupHeader({
    super.key,
    required this.category,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String       category;
  final bool         canMoveUp, canMoveDown;
  final VoidCallback onMoveUp, onMoveDown;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final muted  = onSurf.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 6),
      child: Row(
        children: [
          Text(category.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                  color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
          const Spacer(),
          _MoveBtn(Icons.keyboard_arrow_up_rounded,   canMoveUp,   onMoveUp,   onSurf),
          _MoveBtn(Icons.keyboard_arrow_down_rounded, canMoveDown, onMoveDown, onSurf),
        ],
      ),
    );
  }
}

class _MoveBtn extends StatelessWidget {
  const _MoveBtn(this.icon, this.enabled, this.onTap, this.activeColor);

  final IconData     icon;
  final bool         enabled;
  final VoidCallback onTap;
  final Color        activeColor;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Icon(icon, size: 22,
          color: enabled ? activeColor : activeColor.withValues(alpha: 0.2)),
    ),
  );
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
              color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1, thickness: 0.5,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.40);
    return Center(
      child: Text(message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.6)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text('Error: $message',
        style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.error)),
  );
}