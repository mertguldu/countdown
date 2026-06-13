import 'package:countdown/core/database/database.dart';
import 'package:flutter/material.dart';

import '../../domain/event.dart';
import 'event_list_item.dart';
import 'events_ui_components.dart';

class GroupedEditView extends StatelessWidget {
  const GroupedEditView({
    super.key,
    required this.groups,
    required this.eventType,
    required this.onMoveGroupUp,
    required this.onMoveGroupDown,
    required this.onReorderItem,
    required this.onDelete,
  });

  final List<({String category, List<Event> events})> groups;
  final EventType eventType;
  final void Function(int) onMoveGroupUp;
  final void Function(int) onMoveGroupDown;
  final void Function(int, int, int) onReorderItem;
  final Future<void> Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final slivers = <Widget>[];

    for (int gi = 0; gi < groups.length; gi++) {
      final capturedGi = gi;
      final g = groups[gi];

      slivers.add(SliverToBoxAdapter(
        child: EditGroupHeader(
          key: ValueKey('hdr_${g.category}'),
          category: g.category,
          canMoveUp: capturedGi > 0,
          canMoveDown: capturedGi < groups.length - 1,
          onMoveUp: () => onMoveGroupUp(capturedGi),
          onMoveDown: () => onMoveGroupDown(capturedGi),
        ),
      ));

      slivers.add(SliverReorderableList(
        key: ValueKey('srl_${g.category}'),
        itemCount: g.events.length,
        onReorderItem: (o, n) => onReorderItem(capturedGi, o, n),
        itemBuilder: (ctx, ii) {
          final event = g.events[ii];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(event.id),
            index: ii,
            child: Material(
              color: Colors.transparent,
              child: EventListItem(
                event: event,
                eventType: eventType,
                isEditing: true,
                isDraggable: true,
                onDelete: () => onDelete(event),
              ),
            ),
          );
        },
      ));

      if (capturedGi < groups.length - 1) {
        slivers.add(const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: EventsDivider(),
          ),
        ));
      }
    }
    slivers.add(SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)));
    
    return CustomScrollView(slivers: slivers);
  }
}