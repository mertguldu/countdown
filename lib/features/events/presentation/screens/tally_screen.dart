import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';
import '../widgets/tally_list_item.dart';

/// Tab 3 — Tally counters grouped by category.
/// Supports the same drag-to-reorder / delete edit mode as EventsScreen,
/// but without the active/finished distinction.
/// Normal mode: respects [TallyViewMode] — Category (grouped) or All (flat,
/// newest first). Edit mode: Category view supports drag-to-reorder; All view
/// shows a flat deletable list (no reorder).
class TallyScreen extends ConsumerStatefulWidget {
  const TallyScreen({super.key, this.isEditing = false});
  final bool isEditing;

  @override
  ConsumerState<TallyScreen> createState() => _TallyScreenState();
}

class _TallyScreenState extends ConsumerState<TallyScreen> {
  // ── Edit-mode local state ─────────────────────────────────────────────────
  List<({String category, List<Event> events})> _groups         = [];
  List<Event>                                   _flatEditEvents  = [];
  bool                                          _editInitialized = false;
  ProviderSubscription<AsyncValue<List<Event>>>? _flatSub;

  @override
  void initState() {
    super.initState();
    _runAutoResets();
    if (widget.isEditing) _scheduleEditInit();
  }

  @override
  void didUpdateWidget(TallyScreen old) {
    super.didUpdateWidget(old);
    if (widget.isEditing && !old.isEditing) _scheduleEditInit();
    if (!widget.isEditing && old.isEditing) _tearDown();
  }

  @override
  void dispose() {
    _flatSub?.close();
    super.dispose();
  }

  // ── Auto-reset ────────────────────────────────────────────────────────────

  Future<void> _runAutoResets() async {
    final repo   = ref.read(eventRepositoryProvider);
    final events = await repo.watchByType(EventType.tally).first;
    await repo.processAutoResets(events);
  }

  // ── Edit-mode init ────────────────────────────────────────────────────────

  void _scheduleEditInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flatSub?.close();
      _flatSub = ref.listenManual(
        flatTallyProvider,
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

  void _tearDown() {
    _flatSub?.close();
    _flatSub = null;
    setState(() {
      _editInitialized = false;
      _groups          = [];
      _flatEditEvents  = [];
    });
  }

  void _initFromEvents(List<Event> events) {
    // Grouped view — preserves manual sort order.
    final map = <String, List<Event>>{};
    for (final e in events) {
      (map[e.category] ??= []).add(e);
    }
    _groups = map.entries
        .map((e) => (category: e.key, events: [...e.value]))
        .toList();

    // Flat edit view — newest first.
    _flatEditEvents = [...events]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    for (final g in groups) {
      for (final e in g.events) {
        updates.add((id: e.id, sortOrder: order++));
      }
    }
    ref.read(eventRepositoryProvider).reorder(updates);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _onDelete(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove counter?'),
        content: Text('"${event.title}" will be permanently deleted.'),
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
      _flatEditEvents =
          _flatEditEvents.where((e) => e.id != event.id).toList();
    });

    await ref.read(eventRepositoryProvider).deleteEvent(event.id);
  }

  // ── Tally adjust ──────────────────────────────────────────────────────────

  void _adjust(int id, int delta) =>
      ref.read(eventRepositoryProvider).adjustTallyCount(id, delta);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(tallyViewModeProvider);

    // ── Edit mode ────────────────────────────────────────────────────────────
    if (widget.isEditing) {
      if (!_editInitialized) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }

      // All view — flat deletable list, no drag-to-reorder.
      if (viewMode == TallyViewMode.all) {
        return _FlatTallyEditView(
          events:   _flatEditEvents,
          onDelete: _onDelete,
        );
      }

      // Category view — grouped drag-to-reorder.
      if (_groups.isEmpty) return const _EmptyState();
      return _GroupedEditView(
        groups:          _groups,
        onMoveGroupUp:   _moveGroupUp,
        onMoveGroupDown: _moveGroupDown,
        onReorderItem:   _reorderItem,
        onDelete:        _onDelete,
      );
    }

    // ── Normal mode ──────────────────────────────────────────────────────────

    // All view — flat list, newest first.
    if (viewMode == TallyViewMode.all) {
      return ref.watch(flatTallyAllProvider).when(
        data: (events) => events.isEmpty
            ? const _EmptyState()
            : _FlatTallyList(
                events:      events,
                onIncrement: (id) => _adjust(id, 1),
                onDecrement: (id) => _adjust(id, -1),
              ),
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.error)),
        ),
      );
    }

    // Category view — grouped.
    return ref.watch(groupedTallyProvider).when(
      data: (grouped) => grouped.isEmpty
          ? const _EmptyState()
          : _TallyList(
              grouped:     grouped,
              onIncrement: (id) => _adjust(id, 1),
              onDecrement: (id) => _adjust(id, -1),
            ),
      loading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}

// ── _TallyList ────────────────────────────────────────────────────────────────

class _TallyList extends StatelessWidget {
  const _TallyList({
    required this.grouped,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Map<String, List<Event>> grouped;
  final ValueChanged<int>        onIncrement;
  final ValueChanged<int>        onDecrement;

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
              TallyListItem(
                event:       events[j],
                onIncrement: () => onIncrement(events[j].id),
                onDecrement: () => onDecrement(events[j].id),
              ),
              if (j < events.length - 1) const _Divider(),
            ],
          ],
        );
      },
    );
  }
}

// ── _FlatTallyList ────────────────────────────────────────────────────────────

class _FlatTallyList extends StatelessWidget {
  const _FlatTallyList({
    required this.events,
    required this.onIncrement,
    required this.onDecrement,
  });

  final List<Event>       events;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.only(top: 8, bottom: 120),
    itemCount: events.length,
    separatorBuilder: (_, __) => const _Divider(),
    itemBuilder: (ctx, i) => TallyListItem(
      event:       events[i],
      onIncrement: () => onIncrement(events[i].id),
      onDecrement: () => onDecrement(events[i].id),
    ),
  );
}

// ── _FlatTallyEditView ────────────────────────────────────────────────────────

class _FlatTallyEditView extends StatelessWidget {
  const _FlatTallyEditView({
    required this.events,
    required this.onDelete,
  });

  final List<Event>                  events;
  final Future<void> Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: events.length,
      separatorBuilder: (_, __) => const _Divider(),
      itemBuilder: (ctx, i) => TallyListItem(
        event:     events[i],
        isEditing: true,
        onDelete:  () => onDelete(events[i]),
      ),
    );
  }
}

// ── _GroupedEditView ──────────────────────────────────────────────────────────

class _GroupedEditView extends StatelessWidget {
  const _GroupedEditView({
    required this.groups,
    required this.onMoveGroupUp,
    required this.onMoveGroupDown,
    required this.onReorderItem,
    required this.onDelete,
  });

  final List<({String category, List<Event> events})> groups;
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
              child: TallyListItem(
                event:       event,
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

// ── Shared helpers ────────────────────────────────────────────────────────────

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
          color: enabled
              ? activeColor
              : activeColor.withValues(alpha: 0.2)),
    ),
  );
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.40);
    return Center(
      child: Text('No tallies yet.\nTap + to add one.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.6)),
    );
  }
}