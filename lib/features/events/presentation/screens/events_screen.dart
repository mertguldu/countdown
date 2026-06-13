import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';

// Local Widget Imports
import '../widgets/event_list_view.dart';
import '../widgets/grouped_edit_view.dart';
import '../widgets/finished_edit_view.dart';
import '../widgets/events_ui_components.dart';

enum EditTab { active, finished }

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({
    super.key,
    this.isEditing = false,
    this.editTab = EditTab.active,
    this.eventTypeFilter = EventType.countdown,
  });

  final bool isEditing;
  final EditTab editTab;
  final EventType eventTypeFilter;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  // ── Edit-mode local state ─────────────────────────────────────────────────
  List<({String category, List<Event> events})> _groups = [];
  List<Event> _finishedEvents = [];
  bool _editInitialized = false;
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
      _groups = [];
      _finishedEvents = [];
    });
  }

  void _initFromEvents(List<Event> events) {
    if (_isCountup) {
      final map = <String, List<Event>>{};
      for (final e in events) {
        (map[e.category] ??= []).add(e);
      }
      _groups = map.entries
          .map((e) => (category: e.key, events: [...e.value]))
          .toList();
      _finishedEvents = [];
      return;
    }

    final now = DateTime.now();
    final activeMap = <String, List<Event>>{};
    final finished = <Event>[];
    
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
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
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
      _finishedEvents = _finishedEvents.where((e) => e.id != event.id).toList();
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

      // Countup
      if (_isCountup) {
        return _groups.isEmpty
            ? const EmptyEventsState(message: 'No count-up events yet.\nTap + to add one.')
            : GroupedEditView(
                key: const ValueKey('countup_edit'),
                groups: _groups,
                eventType: EventType.countup,
                onMoveGroupUp: _moveGroupUp,
                onMoveGroupDown: _moveGroupDown,
                onReorderItem: _reorderItem,
                onDelete: _onDelete,
              );
      }

      // Countdown
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: widget.editTab == EditTab.finished
            ? FinishedEditView(
                key: const ValueKey('finished_view'),
                events: _finishedEvents,
                onDelete: _onDelete,
              )
            : (_groups.isEmpty
                ? const EmptyEventsState(
                    key: ValueKey('empty_active'),
                    message: 'No upcoming events.',
                  )
                : GroupedEditView(
                    key: const ValueKey('active_edit'),
                    groups: _groups,
                    eventType: EventType.countdown,
                    onMoveGroupUp: _moveGroupUp,
                    onMoveGroupDown: _moveGroupDown,
                    onReorderItem: _reorderItem,
                    onDelete: _onDelete,
                  )),
      );
    }

    // ── Normal mode ──────────────────────────────────────────────────────────

    // Countup
    if (_isCountup) {
      final countUpFilter = ref.watch(countUpFilterProvider);
      return ref.watch(groupedCountupFilteredProvider).when(
            data: (grouped) => grouped.isEmpty
                ? EmptyEventsState(message: countUpFilter.emptyMessage)
                : EventListView(grouped: grouped, eventType: EventType.countup),
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => EventsErrorState('$e'),
          );
    }

    // Countdown
    return ref.watch(groupedEventsProvider).when(
          data: (grouped) => grouped.isEmpty
              ? const EmptyEventsState(message: 'No events yet.\nTap + to add one.')
              : EventListView(grouped: grouped, eventType: EventType.countdown),
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => EventsErrorState('$e'),
        );
  }
}